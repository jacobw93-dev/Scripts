--CREATE OR REPLACE VIEW HIERARCHY_PL_FILLED_DOWN as(
  WITH CTE AS (
    SELECT
      *,
      ROW_NUMBER() OVER () as ROW_NUM
    FROM
      "PL_HIERARCHY"
  ),
  CTE_1 as (
    SELECT
      COLUMN_0,
      CASE WHEN COLUMN_0 = '' THEN 0 ELSE 1 END as COL0_CHANGE_IND,
      COLUMN_1,
      CASE WHEN COLUMN_1 = '' THEN 0 ELSE 1 END as COL1_CHANGE_IND,
      COLUMN_2,
      CASE WHEN COLUMN_2 = '' THEN 0 ELSE 1 END as COL2_CHANGE_IND,
      COLUMN_3,
      CASE WHEN COLUMN_3 = '' THEN 0 ELSE 1 END as COL3_CHANGE_IND,
      COLUMN_4,
      CASE WHEN COLUMN_4 = '' THEN 0 ELSE 1 END as COL4_CHANGE_IND,
      COLUMN_5,
      CASE WHEN COLUMN_5 = '' THEN 0 ELSE 1 END as COL5_CHANGE_IND,
      COLUMN_6,
      CASE WHEN COLUMN_6 = '' THEN 0 ELSE 1 END as COL6_CHANGE_IND,
      COLUMN_7,
      CASE WHEN COLUMN_7 = '' THEN 0 ELSE 1 END as COL7_CHANGE_IND,
      COLUMN_8,
      CASE WHEN COLUMN_8 = '' THEN 0 ELSE 1 END as COL8_CHANGE_IND,
      COLUMN_9,
      CASE WHEN COLUMN_9 = '' THEN 0 ELSE 1 END as COL9_CHANGE_IND,
      COLUMN_10,
      CASE WHEN COLUMN_10 = '' THEN 0 ELSE 1 END as COL10_CHANGE_IND,
      COLUMN_11,
      CASE WHEN COLUMN_11 = '' THEN 0 ELSE 1 END as COL11_CHANGE_IND,
      ROW_NUM
    FROM
      CTE
    ORDER BY
      ROW_NUM
  ),
  CTE_2 as (
    SELECT
      *,
      SUM(COL0_CHANGE_IND) OVER (ORDER BY ROW_NUM) ROW_GROUP_0,
      SUM(COL1_CHANGE_IND) OVER (ORDER BY ROW_NUM) ROW_GROUP_1,
      SUM(COL2_CHANGE_IND) OVER (ORDER BY ROW_NUM) ROW_GROUP_2,
      SUM(COL3_CHANGE_IND) OVER (ORDER BY ROW_NUM) ROW_GROUP_3,
      SUM(COL4_CHANGE_IND) OVER (ORDER BY ROW_NUM) ROW_GROUP_4,
      SUM(COL5_CHANGE_IND) OVER (ORDER BY ROW_NUM) ROW_GROUP_5,
      SUM(COL6_CHANGE_IND) OVER (ORDER BY ROW_NUM) ROW_GROUP_6,
      SUM(COL7_CHANGE_IND) OVER (ORDER BY ROW_NUM) ROW_GROUP_7,
      SUM(COL8_CHANGE_IND) OVER (ORDER BY ROW_NUM) ROW_GROUP_8,
      SUM(COL9_CHANGE_IND) OVER (ORDER BY ROW_NUM) ROW_GROUP_9,
      SUM(COL10_CHANGE_IND) OVER (ORDER BY ROW_NUM) ROW_GROUP_10,
      SUM(COL11_CHANGE_IND) OVER (ORDER BY ROW_NUM) ROW_GROUP_11
    FROM
      CTE_1
  )
  SELECT
    case when COLUMN_0 <> '' then COLUMN_0 else first_value(COLUMN_0) over (partition by ROW_GROUP_0 order by ROW_NUM) end COLUMN_0_FILLED,
    case when COLUMN_1 <> '' then COLUMN_1 when COLUMN_0 = '' then first_value(COLUMN_1) over (partition by ROW_GROUP_1 order by ROW_NUM) else '' end COLUMN_1_FILLED,
    case when COLUMN_2 <> '' then COLUMN_2 when COLUMN_0 || COLUMN_1 = '' then first_value(COLUMN_2) over (partition by ROW_GROUP_2 order by ROW_NUM) else '' end COLUMN_2_FILLED,
    case when COLUMN_3 <> '' then COLUMN_3 when COLUMN_0 || COLUMN_1 || COLUMN_2 = '' then first_value(COLUMN_3) over (partition by ROW_GROUP_3 order by ROW_NUM) else '' end COLUMN_3_FILLED,
    case when COLUMN_4 <> '' then COLUMN_4 when COLUMN_0 || COLUMN_1 || COLUMN_2 || COLUMN_3 = '' then first_value(COLUMN_4) over (partition by ROW_GROUP_4 order by ROW_NUM) else '' end COLUMN_4_FILLED,
    case when COLUMN_5 <> '' then COLUMN_5 when COLUMN_0 || COLUMN_1 || COLUMN_2 || COLUMN_3 || COLUMN_4 = '' then first_value(COLUMN_5) over (partition by ROW_GROUP_5 order by ROW_NUM) else '' end COLUMN_5_FILLED,
    case when COLUMN_6 <> '' then COLUMN_6 when COLUMN_0 || COLUMN_1 || COLUMN_2 || COLUMN_3 || COLUMN_4 || COLUMN_5 = '' then first_value(COLUMN_6) over (partition by ROW_GROUP_6 order by ROW_NUM) else '' end COLUMN_6_FILLED,
    case when COLUMN_7 <> '' then COLUMN_7 when COLUMN_0 || COLUMN_1 || COLUMN_2 || COLUMN_3 || COLUMN_4 || COLUMN_5 || COLUMN_6 = '' then first_value(COLUMN_7) over (partition by ROW_GROUP_7 order by ROW_NUM) else '' end COLUMN_7_FILLED,
    case when COLUMN_8 <> '' then COLUMN_8 when COLUMN_0 || COLUMN_1 || COLUMN_2 || COLUMN_3 || COLUMN_4 || COLUMN_5 || COLUMN_6 || COLUMN_7 = '' then first_value(COLUMN_8) over (partition by ROW_GROUP_8 order by ROW_NUM) else '' end COLUMN_8_FILLED,
    case when COLUMN_9 <> '' then COLUMN_9 when COLUMN_0 || COLUMN_1 || COLUMN_2 || COLUMN_3 || COLUMN_4 || COLUMN_5 || COLUMN_6 || COLUMN_7 || COLUMN_8 = '' then first_value(COLUMN_9) over (partition by ROW_GROUP_9 order by ROW_NUM) else '' end COLUMN_9_FILLED,
    case when COLUMN_10 <> '' then COLUMN_10 when COLUMN_0 || COLUMN_1 || COLUMN_2 || COLUMN_3 || COLUMN_4 || COLUMN_5 || COLUMN_6 || COLUMN_7 || COLUMN_8 || COLUMN_9 = '' then first_value(COLUMN_10) over (partition by ROW_GROUP_10 order by ROW_NUM) else '' end COLUMN_10_FILLED,
	case when COLUMN_11 <> '' then COLUMN_11 when COLUMN_0 || COLUMN_1 || COLUMN_2 || COLUMN_3 || COLUMN_4 || COLUMN_5 || COLUMN_6 || COLUMN_7 || COLUMN_8 || COLUMN_9 || COLUMN_10 = '' then first_value(COLUMN_11) over (partition by ROW_GROUP_11 order by ROW_NUM) else '' end COLUMN_11_FILLED
 FROM
   CTE_2
 ORDER BY
   ROW_NUM
;
