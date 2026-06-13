/*
=============================================================================
 Q05 - Top 3 produtos mais vendidos dentro de cada categoria
=============================================================================

## Pergunta
Quais os 3 produtos mais vendidos em cada categoria de produto?

## Definições e decisões
- "Mais vendido" = maior NÚMERO DE UNIDADES vendidas (COUNT de order_items),
  não receita. O ranking é por volume de unidades.
- Categoria vem direto de products.product_category_name (em português).
  Optei por NÃO juntar product_category_name_translation: como eu só preciso
  agrupar e rankear, a tradução para inglês não agregaria nada — seria só
  troca de rótulo. (Se o relatório fosse para público internacional, usaria
  pcnt.product_category_name_english.)
- Ranking com ROW_NUMBER(): a pergunta pede EXATAMENTE 3 produtos por
  categoria, então ROW_NUMBER (sem empates compartilhados) é o correto —
  RANK/DENSE_RANK poderiam devolver mais de 3 linhas em caso de empate.
- Desempate determinístico: ORDER BY ... DESC, product_id. Sem o critério de
  desempate, dois produtos com a mesma quantidade ficariam em ordem arbitrária
  e o resultado mudaria a cada execução.
- Produtos sem categoria (product_category_name NULL) entram como um grupo
  próprio; não foram tratados à parte por não serem o foco da análise.

## Conceito
Window function = cálculo sobre um conjunto de linhas relacionado à linha
atual. Aqui: ROW_NUMBER particionado por categoria e ordenado pela quantidade
vendida, para ranquear os produtos dentro de cada categoria.
=============================================================================
*/

WITH agg_ranking_produtos_categoria AS (
    SELECT
        p.product_category_name AS categoria,
        p.product_id            AS produto_id,
        COUNT(oi.order_item_id) AS quantidade_vendida,
        ROW_NUMBER() OVER (
            PARTITION BY p.product_category_name
            ORDER BY COUNT(oi.order_item_id) DESC, p.product_id
        ) AS ranking
    FROM order_items oi
    INNER JOIN products p ON oi.product_id = p.product_id
    GROUP BY p.product_category_name, p.product_id
)
SELECT
    categoria,
    produto_id,
    quantidade_vendida,
    ranking
FROM agg_ranking_produtos_categoria
WHERE ranking <= 3
ORDER BY categoria, ranking;
