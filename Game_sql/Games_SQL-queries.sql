/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Новикова Мария Федоровна
 * Дата: 16.02.2025 г.
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
SELECT 
ROUND(AVG(payer)::numeric,4) AS per_activity --доля платящих игроков от общего количества пользователей, зарегистрированных в игре
FROM fantasy.users;

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
WITH 
-- группируем расы с подсчетом общего количества игроков и платящих игроков
	gr AS (
SELECT 
race_id,
COUNT(id) AS count_id_race, -- количество игроков по каждой расе
SUM(payer) AS count_id_activity_race --количество платящих игроков по каждой расе персонажа
FROM fantasy.users
GROUP BY race_id)
--вычисляем долю платящих игроков в каждой расе на основе СТЕ, присоединяем данные о наименовании расы
SELECT 
r.race_id, --id расы
r.race, --наименование расы
gr.count_id_race,
gr.count_id_activity_race,
ROUND(count_id_activity_race::numeric / count_id_race ,6) AS per_activity_race --доля платящих игроков от общего количества пользователей, зарегистрированных в игре в разрезе каждой расы персонажа
FROM gr 
LEFT JOIN fantasy.race AS r USING(race_id) --присоединяем таблицу с расами для указания названия
ORDER BY per_activity_race DESC;

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
SELECT
'общие данные',
COUNT(transaction_id) AS count_amount, --общее количество покупок
SUM(amount) AS sum_amount, --суммарная стоимость всех покупок
MIN(amount) AS min_amount, --минимальная стоимость покупки
MAX(amount) AS max_amount, --максимальная стоимость покупки
ROUND(AVG(amount)::numeric,2) AS avg_amount, --среднее значение стоимости покупки
PERCENTILE_DISC(0.50) WITHIN GROUP (ORDER BY amount) AS median_amount, -- медиана покупок
ROUND(STDDEV(amount)::numeric,2) AS stand_dev_amount --стандартное отклонение стоимости покупки
FROM fantasy.events
UNION --рассчитываем те же показатели без учета "нулевых" покупок
SELECT
'без нулевых покупок',
COUNT(transaction_id) AS count_amount, --общее количество покупок
SUM(amount) AS sum_amount, --суммарная стоимость всех покупок
MIN(amount) AS min_amount, --минимальная стоимость покупки
MAX(amount) AS max_amount, --максимальная стоимость покупки
ROUND(AVG(amount)::numeric,2) AS avg_amount, --среднее значение стоимости покупки
PERCENTILE_DISC(0.50) WITHIN GROUP (ORDER BY amount) AS median_amount, -- медиана покупок
ROUND(STDDEV(amount)::numeric,2) AS stand_dev_amount --стандартное отклонение стоимости покупки
FROM fantasy.events
WHERE amount>0;

-- 2.2: Аномальные нулевые покупки:
SELECT 
COUNT(*) FILTER (WHERE amount = 0) AS amount_zero, --количество покупок со стоимостью 0
COUNT(*) AS count_amount, --общее количеством покупок
ROUND(COUNT(*) FILTER (WHERE amount = 0)::numeric / COUNT(*),4) AS per_zero -- --доля "нулевых" покупок в общем количестве покупок
FROM fantasy.events;

-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:
WITH 
--группируем игроков по группам платящие и неплатящие
	gu AS ( 
SELECT
u.payer,
e.id,
COUNT(e.amount ) AS count_amount, --количество покупок каждого игрока по группе
SUM(e.amount ) AS sum_amount --суммарная стоимость покупок каждого игрока по группе
FROM fantasy.events AS e
LEFT JOIN fantasy.users AS u USING(id) 
WHERE e.amount >0 --исключаем 'нулевые'покупки
GROUP BY u.payer, e.id) --исключаем дубликаты 
--основной запрос
SELECT 
CASE --группируем игроков по признаку, через CASE WHEN THEN переименовываем.
	WHEN payer = 1 
	THEN 'платящий'
	ELSE 'неплатящий'
	END AS group_gamers,	
COUNT(id) AS count_gamers, --количество игроков по каждой группе
AVG(count_amount)::int AS avg_count_amount, --среднее количество покупок каждого игрока по каждой группе
AVG(sum_amount)::int AS avg_sum_amount --средняя суммарная стоимость покупок каждого игрока по каждой группе
FROM gu
GROUP BY payer
ORDER BY payer DESC;

-- 2.4: Популярные эпические предметы:
WITH 
--подзапрос для группировки покупок по эпич.предметам
	gt AS ( 
SELECT
item_code,
COUNT(amount) AS count_amount_item, --количество покупок каждого эпич.предмета
COUNT(DISTINCT id) AS count_gamers,--количество игроков, приобретающих каждый эпич.предмет
--подзапрос суммарного количества уникальных игроков всех эпич.предметов
(SELECT COUNT(DISTINCT id) FROM fantasy.events WHERE amount>0) AS all_gamers 
FROM fantasy.events
WHERE amount>0 --исключаем 'нулевые'покупки
GROUP BY item_code)
--основной запрос, соединяем данные, рассчитываем доли
SELECT 
gt.item_code,
i.game_items, --название эпич. предмета
gt.count_amount_item,
ROUND(gt.count_amount_item::numeric / (SUM(gt.count_amount_item) OVER()),6) AS per_amount_item, --доля покупок каждого эпич.предмета
ROUND((gt.count_gamers::numeric / gt.all_gamers), 6) AS per_gamers --доля игроков, которые хотя бы раз покупали этот предмет
FROM gt
LEFT JOIN fantasy.items AS i USING(item_code)
ORDER BY per_amount_item DESC;

-- Часть 2. Решение ad hoc-задач
-- Задача 1. Зависимость активности игроков от расы персонажа:
WITH 
--подзапрос для группировки покупок по эпич.предметам/ ДОБАВИЛА ДАННЫЕ ПО ДОЛЕ, ВИДИМО НЕПРАВИЛЬНО ПОНЯЛА ЗАДАНИЕ. ПОДПРАВИЛА ФИЛЬТРАЦИЮ
	gr AS ( 
SELECT
race_id,
COUNT(id) AS count_gamers,--количество игроков, которые совершают внутриигровые покупки, по каждой расе
ROUND(AVG(payer)::NUMERIC,4) AS per_payer --доля платящих игроков от количества игроков
FROM  fantasy.users
WHERE id IN 
		(SELECT id FROM fantasy.events WHERE amount>0)
GROUP BY race_id),
--подзапрос для расчета общего количества зарегистрированных игроков
	allg AS ( 
SELECT
race_id,
COUNT(id) AS count_all_gamers --общее количество зарегистрированных игроков /УБРАЛА DISTINCT, ДА, ОНА ТУТ ДЕЙСТВИТЕЛЬНО НЕ НУЖНА
FROM fantasy.users
GROUP BY race_id),
---подзапрос для размеров и количества покупок по каждому игроку в разрезе рас
	amountg AS ( 
SELECT
u.race_id,
e.id,
COUNT(e.amount) AS count_amount,--количество покупок каждого игрока
AVG(e.amount) AS avg_amount, --средний размер покупки каждого игрока
SUM(e.amount) AS sum_amonut --сумма покупок каждого игрока
FROM fantasy.events AS e
LEFT JOIN fantasy.users AS u USING(id)
WHERE amount>0 --исключаем 'нулевые'покупки
GROUP BY race_id,e.id)
--основной запрос, соединяем данные, определяем доли
SELECT 
gr.race_id,
r.race, --название расы
allg.count_all_gamers, --общее количество зарегистрированных игроков
gr.count_gamers, --количество игроков, которые совершают внутриигровые покупки, по каждой расе
ROUND(gr.count_gamers::numeric/allg.count_all_gamers , 4) AS per_payer_in_all, --доля игроков, которые совершают внутриигровые покупки, от общего количества
gr.per_payer, --доля платящих игроков от количества игроков, которые совершили покупки
ROUND(AVG(amountg.count_amount)::NUMERIC,2) AS avg_count_amount, --среднее количество покупок на одного игрока
ROUND(AVG(amountg.avg_amount)::NUMERIC,0) AS avg_sum_amount, --средняя стоимость одной покупки на одного игрока
ROUND(AVG(amountg.sum_amonut)::NUMERIC,0) AS avg_sum_amount_all --средняя суммарная стоимость всех покупок на одного игрока
FROM gr 
INNER JOIN allg ON gr.race_id = allg.race_id --здесь и во 2 задаче соединяла через ON, поскольку много соединений, побоялась что все перепутается из-за большого количества столбцов с одинаковым названием
INNER JOIN amountg ON allg.race_id = amountg.race_id
LEFT JOIN fantasy.race AS r ON amountg.race_id = r.race_id --присоединение таблицы для вывода наименования расы
GROUP BY gr.race_id, r.race, allg.count_all_gamers,gr.count_gamers,gr.per_payer
ORDER BY r.race;

-- Задача 2: Частота покупок
WITH 
 --подзапрос на нахождение среднего интервала по каждому игроку и группировке игроков
	gdays AS (SELECT
id,
AVG(interval_date) AS avg_interval_date,  --среднее количество дней между покупками на одного игрока
NTILE(3) OVER (ORDER BY AVG(interval_date)) AS group_id --группировка игроков, где 1- 'высокая частота', 2- 'умеренная частота', 3-'низкая частота'
FROM (SELECT --подзапрос на нахождение интервала между покупками по каждому игроку
		id,
		(date::date - LAG(date::date) OVER (PARTITION BY id ORDER BY date)) AS interval_date --рассчитываем интервал по покупкам по каждому игроку
		FROM fantasy.events
		WHERE amount>0) AS dg
GROUP BY id
HAVING id IN (SELECT id --исключаем игроков с 'нулевыми'покупками и менее активных игроков с количеством покупок <25
    				FROM fantasy.events
    				GROUP BY id
    				HAVING COUNT(amount)>=25)),
--подзапрос на подсчет количества покупок по каждому игроку
	gg AS ( 
SELECT
id,
COUNT(amount) AS count_amount --количество покупок по каждому игроку
FROM fantasy.events
WHERE amount>0 
GROUP BY id
HAVING COUNT(amount)>=25) 
--соединяем все подзапросы, считаем средние показатели по группе
SELECT
CASE --присваиванием имя группам
	WHEN gdays.group_id = 1
	THEN 'высокая частота'
	WHEN gdays.group_id = 2
	THEN 'умеренная частота'
	ELSE 'низкая частота'
	END AS name_group,
COUNT(gdays.id) AS count_gamers, --количество игроков, которые совершили покупки /количество игроков одинаковая, поскольку NTILE делит на примерно одинаковое количество строк (игроков) в группе
SUM(u.payer) AS count_payer, --количество платящих игроков, совершивших покупки
ROUND(SUM(u.payer)::numeric /COUNT(gdays.id),4) AS per_payer, --доля платящих игроков, совершивших покупки от общего количества игроков, совершивших покупку
ROUND(AVG(gg.count_amount)::numeric,2) AS avg_count_amount, --среднее количество покупок на одного игрока
ROUND(AVG(gdays.avg_interval_date)::numeric,2) AS avg_interval_date ---среднее количество дней между покупками на одного игрока по группе
FROM gdays
INNER JOIN gg ON gg.id = gdays.id
LEFT JOIN fantasy.users AS u ON gdays.id = u.id --левое присоединение, чтобы учесть только игроков по критериям отбора
GROUP BY gdays.group_id, name_group;
