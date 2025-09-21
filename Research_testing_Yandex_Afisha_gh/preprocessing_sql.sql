-- Анализ данных с помощью SQL. Построение [дашборда](https://datalens.yandex/kc5svnmg3oqq5?_theme=dark)

-- Цель: знакомство с данными, предобработка, расчет ключевых метрик.

-- 1. Получение общих данных:

SELECT
ROUND(SUM(revenue)::numeric, 2) AS total_revenue,
COUNT(*) AS total_orders,
ROUND(AVG(revenue)::numeric, 2) AS avg_revenue_per_order,
COUNT(DISTINCT user_id) AS total_users,
currency_code
FROM afisha.purchases
GROUP BY currency_code
ORDER BY total_revenue DESC

-- 2. Изучение распределения выручки в разрезе устройств:

WITH set_config_precode AS (
  SELECT set_config('synchronize_seqscans', 'off', true)
)
SELECT
device_type_canonical,
SUM(revenue) total_revenue,
COUNT(*) total_orders,
AVG(revenue) avg_revenue_per_order,
ROUND((SUM(revenue) / (SELECT SUM(revenue) FROM afisha.purchases WHERE currency_code = 'rub'))::numeric , 3) AS revenue_share
FROM afisha.purchases
WHERE currency_code = 'rub'
GROUP BY device_type_canonical
ORDER BY revenue_share DESC

-- 3. Изучение распределения выручки в разрезе типа мероприятий
-- Для заказов в рублях вычислите распределение количества заказов и их выручку в зависимости от типа мероприятия event_type_main. 

SELECT
e.event_type_main,
SUM(p.revenue) total_revenue,
COUNT(*) total_orders,
AVG(p.revenue) avg_revenue_per_order,
COUNT(DISTINCT e.event_name_code) total_event_name,
AVG(p.tickets_count) avg_tickets,
SUM(p.revenue) / SUM(p.tickets_count) avg_ticket_revenue,
ROUND((SUM(p.revenue) / (SELECT SUM(revenue) FROM afisha.purchases WHERE currency_code = 'rub'))::numeric , 3) AS revenue_share
FROM afisha.purchases p
LEFT JOIN afisha.events e USING(event_id)
WHERE p.currency_code = 'rub'
GROUP BY e.event_type_main
ORDER BY total_orders DESC;

-- 4. Динамика изменения значений
-- На дашборде понадобится показать динамику изменения ключевых метрик и параметров. Для заказов в рублях вычислите изменение выручки, количества заказов, уникальных клиентов и средней стоимости одного заказа в недельной динамике. 

SELECT
DATE_TRUNC ('week', created_dt_msk)::date week,
SUM(revenue) total_revenue,
COUNT(*) total_orders,
COUNT (DISTINCT user_id) total_users,
SUM(revenue) / COUNT(*) revenue_per_order
FROM afisha.purchases
WHERE currency_code = 'rub'
GROUP BY week
ORDER BY week;

-- 5. Выделение топ-сегментов
-- Выведите топ-7 регионов по значению общей выручки, включив только заказы за рубли. 

SELECT
r.region_name,
SUM(revenue) total_revenue,
COUNT(*) total_orders,
COUNT(DISTINCT user_id) total_users,
SUM(tickets_count) total_tickets,
SUM(revenue) /SUM(tickets_count) one_ticket_cost
FROM afisha.purchases p
LEFT JOIN afisha.events e USING(event_id)
LEFT JOIN afisha.city c USING(city_id)
LEFT JOIN afisha.regions r USING(region_id)
WHERE p.currency_code = 'rub'
GROUP BY r.region_name
ORDER BY total_revenue DESC
LIMIT 7;
