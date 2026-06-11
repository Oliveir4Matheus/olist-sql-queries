/*
**4. Taxa de pedidos atrasados por estado** (entrega real > estimada). Apenas estados com >100 pedidos.

- **Foco:**  `CASE WHEN`, agregação com filtro, `HAVING`.
- **Feito quando:**  lista UF + taxa_atraso_% em ordem decrescente.


Anotações da analise:
>> Para obter os estados irei utilizar a tabela customers, pois se eu fosse utilizar a tabela sellers que também possui state
eu teria dados incorretos, pois o mesmo pedido pode ter itens de diferentes vendedores.

>> Como vamos considerar apenas os pedidos entregues, vou precisar fazer alguns filtros ( status = 'delivered' e delivery_date IS NOT NULL )
*/

WITH
	pedidos_estado AS (
		SELECT
			o.order_id,
			o.order_delivered_customer_date AS data_entrega_real,
			o.order_estimated_delivery_date AS data_entrega_estimada,
			c.customer_state
		FROM
			orders AS o
		INNER JOIN customers AS c ON c.customer_id = o.customer_id
		WHERE
			o.order_delivered_customer_date IS NOT NULL AND o.order_status = 'delivered'
)
	SELECT
		pc.customer_state AS estado,
		COUNT(*) AS total_pedidos,
		SUM(
			CASE
				WHEN pc.data_entrega_real > pc.data_entrega_estimada THEN 1 ELSE 0 END
		) AS qtd_atrasada,
		ROUND(100.0 * SUM(
			CASE
				WHEN pc.data_entrega_real > pc.data_entrega_estimada THEN 1 ELSE 0 END
		) / COUNT(*), 1) AS pct_atrasado
	FROM
		pedidos_estado AS pc
	GROUP BY
		pc.customer_state
	HAVING
		COUNT(*) > 100
	ORDER BY pct_atrasado DESC
