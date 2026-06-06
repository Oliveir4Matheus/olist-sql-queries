/*
=============================================================================
 Q01 - Top 10 cidades por volume de pedidos (com ticket médio)
=============================================================================

## Pergunta
Quais as 10 cidades que mais vendem (maior número de pedidos), e qual o
ticket médio de cada uma?

## Definições
- Pedidos únicos = contagem de pedidos distintos (order_id).
- Ticket médio   = média do valor de cada pedido, onde o valor do pedido é a
                   soma de (price + freight_value) de todos os seus itens.

## Tabelas / colunas
- Cidade do cliente: customers.customer_city, customers.customer_state
- Pedidos:           orders.order_id, orders.customer_id, orders.order_status
- Itens do pedido:   order_items.order_id, order_items.price, order_items.freight_value

## Achados e decisões
1. Cidade pelo CLIENTE, não pelo seller. A validação (Query 1) mostra que um
   mesmo pedido pode ter itens de sellers em cidades diferentes, o que
   inviabiliza usar seller_city como a "cidade do pedido". customer_city é
   única por pedido e é a escolha correta.

2. Filtro de status. Comparando a contagem de pedidos entre orders,
   order_items e order_payments (Query 2) há divergência esperada — nem todo
   pedido foi pago/entregue. Para a análise considero apenas pedidos em
   status efetivos: approved, invoiced, processing, shipped, delivered.

3. Composição do ticket. Uso price + freight_value, pois o ticket médio deve
   refletir o custo final pago pelo cliente, frete incluído.

4. Ordenação. Ordeno por NÚMERO DE PEDIDOS (volume), pois a pergunta é sobre
   as cidades que mais vendem. O ticket médio entra como métrica secundária
   de cada cidade, não como critério de ordenação.

5. Outliers. Na distribuição (Query 3), ~76% das cidades concentram uma
   fração pequena dos pedidos (cauda longa de cidades com pouquíssimos
   pedidos). Cheguei a considerar um corte mínimo de pedidos por cidade, mas
   como a ordenação final é por VOLUME, o top 10 já é composto pelas maiores
   cidades — o corte se torna desnecessário e foi removido da query final.

6. Normalização. Aplico UPPER() em customer_city para evitar que variações de
   caixa ("sao paulo" vs "Sao Paulo") sejam contadas como cidades distintas.
=============================================================================
*/


/* ---------------------------------------------------------------------------
 Query 1 — Validação: um pedido pode ter itens de sellers em cidades diferentes?
--------------------------------------------------------------------------- */
WITH validacao AS (
    SELECT
        oi.order_id,
        COUNT(DISTINCT s.seller_city) AS qtd_cidades
    FROM order_items oi
    INNER JOIN sellers s ON oi.seller_id = s.seller_id
    GROUP BY oi.order_id
)
SELECT COUNT(*) AS pedidos_multi_cidade
FROM validacao
WHERE qtd_cidades > 1;


/* ---------------------------------------------------------------------------
 Query 2 — Sanidade: contagem de pedidos por tabela
--------------------------------------------------------------------------- */
WITH
    p_order AS (
        SELECT COUNT(o.order_id) AS pedidos_order FROM orders o
    ),
    p_order_items AS (
        SELECT COUNT(DISTINCT oi.order_id) AS pedidos_order_items FROM order_items oi
    ),
    p_order_payment AS (
        SELECT COUNT(DISTINCT op.order_id) AS pedidos_pagos FROM order_payments op
    )
SELECT
    p_order.pedidos_order,
    p_order_items.pedidos_order_items,
    p_order_payment.pedidos_pagos
FROM p_order, p_order_items, p_order_payment;


/* ---------------------------------------------------------------------------
 Query 3 — Distribuição de pedidos por cidade (análise de outliers)
--------------------------------------------------------------------------- */
WITH n_pedidos_cidades AS (
    SELECT
        c.customer_city AS cidade,
        COUNT(*) AS n_pedidos
    FROM orders o
    INNER JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_status IN ('approved','invoiced','processing','shipped','delivered')
    GROUP BY c.customer_city
),
total_pedidos AS (
    SELECT SUM(n_pedidos) AS t_pedidos FROM n_pedidos_cidades
),
total_cidades AS (
    SELECT COUNT(*) AS t_cidades FROM n_pedidos_cidades
)
SELECT
    CASE
        WHEN n_pedidos = 1            THEN '1'
        WHEN n_pedidos BETWEEN 2 AND 4   THEN '2-4'
        WHEN n_pedidos BETWEEN 5 AND 9   THEN '5-9'
        WHEN n_pedidos BETWEEN 10 AND 49 THEN '10-49'
        ELSE '50+'
    END AS faixa,
    COUNT(*) AS qtd_cidades,
    SUM(n_pedidos) AS qtd_pedidos,
    ROUND(COUNT(*)       * 100.0 / tc.t_cidades, 1) AS pct_cidades,
    ROUND(SUM(n_pedidos) * 100.0 / tp.t_pedidos, 1) AS pct_pedidos
FROM n_pedidos_cidades
CROSS JOIN total_pedidos tp
CROSS JOIN total_cidades tc
GROUP BY faixa, tc.t_cidades, tp.t_pedidos
ORDER BY MIN(n_pedidos);


/* ---------------------------------------------------------------------------
 Query principal — Top 10 cidades por volume de pedidos (com ticket médio)
--------------------------------------------------------------------------- */
WITH pedidos_cidade AS (
    SELECT
        o.order_id,
        UPPER(ct.customer_city) AS cidade,
        ct.customer_state       AS estado,
        SUM(oi.price + oi.freight_value) AS ticket_pedido
    FROM customers AS ct
    INNER JOIN orders      AS o  ON o.customer_id = ct.customer_id
    INNER JOIN order_items AS oi ON oi.order_id   = o.order_id
    WHERE o.order_status IN ('approved','shipped','delivered','processing','invoiced')
    GROUP BY o.order_id, ct.customer_city, ct.customer_state
)
SELECT
    cidade,
    estado,
    COUNT(order_id)              AS n_pedidos,
    ROUND(AVG(ticket_pedido), 2) AS ticket_medio
FROM pedidos_cidade
GROUP BY cidade, estado
ORDER BY n_pedidos DESC
LIMIT 10;
