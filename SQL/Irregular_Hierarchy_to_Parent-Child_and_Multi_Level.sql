create procedure "_SYS_BIC"."zplayground.WALCZAKJ/CVC_C_HIER_AB_DEC_MULTI_LVL/proc" ( OUT var_out "_SYS_BIC"."zplayground.WALCZAKJ/CVC_C_HIER_AB_DEC_MULTI_LVL/proc/tabletype/VAR_OUT" ) language sqlscript sql security definer reads sql data as  /********* Begin Procedure Script ************/
 BEGIN
 	"CTE" =
 	(
 		SELECT
 			"COLUMN_0"  ,
 			"COLUMN_1"  ,
 			"COLUMN_2"  ,
 			"COLUMN_3"  ,
 			"COLUMN_4"  ,
 			"COLUMN_5"  ,
 			"COLUMN_6"  ,
 			"COLUMN_7"  ,
 			"COLUMN_8"  ,
 			"COLUMN_9"  ,
 			"COLUMN_10" ,
 			"COLUMN_11" ,
 			"COLUMN_12" ,
 			"COLUMN_13" ,
 			ROW_NUMBER() OVER () as ROW_NUM
 		FROM
 			"WALCZAKJ"."FI_HIER_AB_1"
 	)
 	;
 	"CTE_1" =
 	(
 		SELECT
 			COLUMN_0 ,
 			CASE
 				WHEN COLUMN_0 = ''
 					THEN 0
 					ELSE 1
 			END as COL0_CHANGE_IND ,
 			COLUMN_1               ,
 			CASE
 				WHEN COLUMN_1 = ''
 					THEN 0
 					ELSE 1
 			END as COL1_CHANGE_IND ,
 			COLUMN_2               ,
 			CASE
 				WHEN COLUMN_2 = ''
 					THEN 0
 					ELSE 1
 			END as COL2_CHANGE_IND ,
 			COLUMN_3               ,
 			CASE
 				WHEN COLUMN_3 = ''
 					THEN 0
 					ELSE 1
 			END as COL3_CHANGE_IND ,
 			COLUMN_4               ,
 			CASE
 				WHEN COLUMN_4 = ''
 					THEN 0
 					ELSE 1
 			END as COL4_CHANGE_IND ,
 			COLUMN_5               ,
 			CASE
 				WHEN COLUMN_5 = ''
 					THEN 0
 					ELSE 1
 			END as COL5_CHANGE_IND ,
 			COLUMN_6               ,
 			CASE
 				WHEN COLUMN_6 = ''
 					THEN 0
 					ELSE 1
 			END as COL6_CHANGE_IND ,
 			COLUMN_7               ,
 			CASE
 				WHEN COLUMN_7 = ''
 					THEN 0
 					ELSE 1
 			END as COL7_CHANGE_IND ,
 			COLUMN_8               ,
 			CASE
 				WHEN COLUMN_8 = ''
 					THEN 0
 					ELSE 1
 			END as COL8_CHANGE_IND ,
 			COLUMN_9               ,
 			CASE
 				WHEN COLUMN_9 = ''
 					THEN 0
 					ELSE 1
 			END as COL9_CHANGE_IND ,
 			COLUMN_10              ,
 			CASE
 				WHEN COLUMN_10 = ''
 					THEN 0
 					ELSE 1
 			END as COL10_CHANGE_IND ,
 			COLUMN_11               ,
 			CASE
 				WHEN COLUMN_11 = ''
 					THEN 0
 					ELSE 1
 			END as COL11_CHANGE_IND ,
 			COLUMN_12               ,
 			CASE
 				WHEN COLUMN_12 = ''
 					THEN 0
 					ELSE 1
 			END as COL12_CHANGE_IND ,
 			COLUMN_13               ,
 			CASE
 				WHEN COLUMN_13 = ''
 					THEN 0
 					ELSE 1
 			END as COL13_CHANGE_IND ,
 			ROW_NUM
 		FROM
 			:CTE
 		ORDER BY
 			ROW_NUM
 	)
 	;
 	"CTE_2" =
 	(
 		SELECT
 			"COLUMN_0"                                                  ,
 			"COL0_CHANGE_IND"                                           ,
 			"COLUMN_1"                                                  ,
 			"COL1_CHANGE_IND"                                           ,
 			"COLUMN_2"                                                  ,
 			"COL2_CHANGE_IND"                                           ,
 			"COLUMN_3"                                                  ,
 			"COL3_CHANGE_IND"                                           ,
 			"COLUMN_4"                                                  ,
 			"COL4_CHANGE_IND"                                           ,
 			"COLUMN_5"                                                  ,
 			"COL5_CHANGE_IND"                                           ,
 			"COLUMN_6"                                                  ,
 			"COL6_CHANGE_IND"                                           ,
 			"COLUMN_7"                                                  ,
 			"COL7_CHANGE_IND"                                           ,
 			"COLUMN_8"                                                  ,
 			"COL8_CHANGE_IND"                                           ,
 			"COLUMN_9"                                                  ,
 			"COL9_CHANGE_IND"                                           ,
 			"COLUMN_10"                                                 ,
 			"COL10_CHANGE_IND"                                          ,
 			"COLUMN_11"                                                 ,
 			"COL11_CHANGE_IND"                                          ,
 			"COLUMN_12"                                                 ,
 			"COL12_CHANGE_IND"                                          ,
 			"COLUMN_13"                                                 ,
 			"COL13_CHANGE_IND"                                          ,
 			"ROW_NUM"                                                   ,
 			SUM(COL0_CHANGE_IND) OVER ( ORDER BY ROW_NUM)  ROW_GROUP_0  ,
 			SUM(COL1_CHANGE_IND) OVER ( ORDER BY ROW_NUM)  ROW_GROUP_1  ,
 			SUM(COL2_CHANGE_IND) OVER ( ORDER BY ROW_NUM)  ROW_GROUP_2  ,
 			SUM(COL3_CHANGE_IND) OVER ( ORDER BY ROW_NUM)  ROW_GROUP_3  ,
 			SUM(COL4_CHANGE_IND) OVER ( ORDER BY ROW_NUM)  ROW_GROUP_4  ,
 			SUM(COL5_CHANGE_IND) OVER ( ORDER BY ROW_NUM)  ROW_GROUP_5  ,
 			SUM(COL6_CHANGE_IND) OVER ( ORDER BY ROW_NUM)  ROW_GROUP_6  ,
 			SUM(COL7_CHANGE_IND) OVER ( ORDER BY ROW_NUM)  ROW_GROUP_7  ,
 			SUM(COL8_CHANGE_IND) OVER ( ORDER BY ROW_NUM)  ROW_GROUP_8  ,
 			SUM(COL9_CHANGE_IND) OVER ( ORDER BY ROW_NUM)  ROW_GROUP_9  ,
 			SUM(COL10_CHANGE_IND) OVER ( ORDER BY ROW_NUM) ROW_GROUP_10 ,
 			SUM(COL11_CHANGE_IND) OVER ( ORDER BY ROW_NUM) ROW_GROUP_11 ,
 			SUM(COL12_CHANGE_IND) OVER ( ORDER BY ROW_NUM) ROW_GROUP_12 ,
 			SUM(COL13_CHANGE_IND) OVER ( ORDER BY ROW_NUM) ROW_GROUP_13
 		FROM
 			:CTE_1
 	)
 	;
 	"CTE_3" =
 	(
 		SELECT
 			case
 				when COLUMN_0 <> ''
 					then COLUMN_0
 					else first_value(COLUMN_0) over (partition by ROW_GROUP_0 order by
 													 ROW_NUM)
 			end COLUMN_0_FILLED ,
 			case
 				when COLUMN_1 <> ''
 					then COLUMN_1
 				when COLUMN_0 = ''
 					then first_value(COLUMN_1) over (partition by ROW_GROUP_1 order by
 													 ROW_NUM)
 					else ''
 			end COLUMN_1_FILLED ,
 			case
 				when COLUMN_2 <> ''
 					then COLUMN_2
 				when COLUMN_0 || COLUMN_1 = ''
 					then first_value(COLUMN_2) over (partition by ROW_GROUP_2 order by
 													 ROW_NUM)
 					else ''
 			end COLUMN_2_FILLED ,
 			case
 				when COLUMN_3 <> ''
 					then COLUMN_3
 				when COLUMN_0 || COLUMN_1 || COLUMN_2 = ''
 					then first_value(COLUMN_3) over (partition by ROW_GROUP_3 order by
 													 ROW_NUM)
 					else ''
 			end COLUMN_3_FILLED ,
 			case
 				when COLUMN_4 <> ''
 					then COLUMN_4
 				when COLUMN_0 || COLUMN_1 || COLUMN_2 || COLUMN_3 = ''
 					then first_value(COLUMN_4) over (partition by ROW_GROUP_4 order by
 													 ROW_NUM)
 					else ''
 			end COLUMN_4_FILLED ,
 			case
 				when COLUMN_5 <> ''
 					then COLUMN_5
 				when COLUMN_0 || COLUMN_1 || COLUMN_2 || COLUMN_3 || COLUMN_4 = ''
 					then first_value(COLUMN_5) over (partition by ROW_GROUP_5 order by
 													 ROW_NUM)
 					else ''
 			end COLUMN_5_FILLED ,
 			case
 				when COLUMN_6 <> ''
 					then COLUMN_6
 				when COLUMN_0 || COLUMN_1 || COLUMN_2 || COLUMN_3 || COLUMN_4 || COLUMN_5 = ''
 					then first_value(COLUMN_6) over (partition by ROW_GROUP_6 order by
 													 ROW_NUM)
 					else ''
 			end COLUMN_6_FILLED ,
 			case
 				when COLUMN_7 <> ''
 					then COLUMN_7
 				when COLUMN_0 || COLUMN_1 || COLUMN_2 || COLUMN_3 || COLUMN_4 || COLUMN_5 || COLUMN_6 = ''
 					then first_value(COLUMN_7) over (partition by ROW_GROUP_7 order by
 													 ROW_NUM)
 					else ''
 			end COLUMN_7_FILLED ,
 			case
 				when COLUMN_8 <> ''
 					then COLUMN_8
 				when COLUMN_0 || COLUMN_1 || COLUMN_2 || COLUMN_3 || COLUMN_4 || COLUMN_5 || COLUMN_6 || COLUMN_7 = ''
 					then first_value(COLUMN_8) over (partition by ROW_GROUP_8 order by
 													 ROW_NUM)
 					else ''
 			end COLUMN_8_FILLED ,
 			case
 				when COLUMN_9 <> ''
 					then COLUMN_9
 				when COLUMN_0 || COLUMN_1 || COLUMN_2 || COLUMN_3 || COLUMN_4 || COLUMN_5 || COLUMN_6 || COLUMN_7 || COLUMN_8 = ''
 					then first_value(COLUMN_9) over (partition by ROW_GROUP_9 order by
 													 ROW_NUM)
 					else ''
 			end COLUMN_9_FILLED ,
 			case
 				when COLUMN_10 <> ''
 					then COLUMN_10
 				when COLUMN_0 || COLUMN_1 || COLUMN_2 || COLUMN_3 || COLUMN_4 || COLUMN_5 || COLUMN_6 || COLUMN_7 || COLUMN_8 || COLUMN_9 = ''
 					then first_value(COLUMN_10) over (partition by ROW_GROUP_10 order by
 													  ROW_NUM)
 					else ''
 			end COLUMN_10_FILLED ,
 			case
 				when COLUMN_11 <> ''
 					then COLUMN_11
 				when COLUMN_0 || COLUMN_1 || COLUMN_2 || COLUMN_3 || COLUMN_4 || COLUMN_5 || COLUMN_6 || COLUMN_7 || COLUMN_8 || COLUMN_9 || COLUMN_10 = ''
 					then first_value(COLUMN_11) over (partition by ROW_GROUP_11 order by
 													  ROW_NUM)
 					else ''
 			end COLUMN_11_FILLED ,
 			case
 				when COLUMN_12 <> ''
 					then COLUMN_12
 				when COLUMN_0 || COLUMN_1 || COLUMN_2 || COLUMN_3 || COLUMN_4 || COLUMN_5 || COLUMN_6 || COLUMN_7 || COLUMN_8 || COLUMN_9 || COLUMN_10 || COLUMN_11 = ''
 					then first_value(COLUMN_12) over (partition by ROW_GROUP_12 order by
 													  ROW_NUM)
 					else ''
 			end COLUMN_12_FILLED ,
 			case
 				when COLUMN_13 <> ''
 					then COLUMN_13
 				when COLUMN_0 || COLUMN_1 || COLUMN_2 || COLUMN_3 || COLUMN_4 || COLUMN_5 || COLUMN_6 || COLUMN_7 || COLUMN_8 || COLUMN_9 || COLUMN_10 || COLUMN_11 || COLUMN_12 = ''
 					then first_value(COLUMN_13) over (partition by ROW_GROUP_13 order by
 													  ROW_NUM)
 					else ''
 			end COLUMN_13_FILLED ,
 			ROW_NUM
 		FROM
 			:CTE_2
 	)
 	;
 	CTE_4 =
 	(
 		SELECT   DISTINCT
 			CASE
 				WHEN ROW_NUM = 3
 					THEN '1'
 					ELSE ''
 			END as ROOT_IND ,
 			CASE
 				WHEN COLUMN_1_FILLED <> ''
 					THEN COLUMN_0_FILLED
 					ELSE ''
 			END as COLUMN_0_FILLED ,
 			CASE
 				WHEN COLUMN_2_FILLED <> ''
 					THEN COLUMN_1_FILLED
 					ELSE ''
 			END as COLUMN_1_FILLED ,
 			CASE
 				WHEN COLUMN_3_FILLED <> ''
 					THEN COLUMN_2_FILLED
 					ELSE ''
 			END as COLUMN_2_FILLED ,
 			CASE
 				WHEN COLUMN_4_FILLED <> ''
 					THEN COLUMN_3_FILLED
 					ELSE ''
 			END as COLUMN_3_FILLED ,
 			CASE
 				WHEN COLUMN_5_FILLED <> ''
 					THEN COLUMN_4_FILLED
 					ELSE ''
 			END as COLUMN_4_FILLED ,
 			CASE
 				WHEN COLUMN_6_FILLED <> ''
 					THEN COLUMN_5_FILLED
 					ELSE ''
 			END as COLUMN_5_FILLED ,
 			CASE
 				WHEN COLUMN_7_FILLED <> ''
 					THEN COLUMN_6_FILLED
 					ELSE ''
 			END as COLUMN_6_FILLED ,
 			CASE
 				WHEN COLUMN_8_FILLED <> ''
 					THEN COLUMN_7_FILLED
 					ELSE ''
 			END as COLUMN_7_FILLED ,
 			CASE
 				WHEN COLUMN_9_FILLED <> ''
 					THEN COLUMN_8_FILLED
 					ELSE ''
 			END as COLUMN_8_FILLED ,
 			CASE
 				WHEN COLUMN_10_FILLED <> ''
 					THEN COLUMN_9_FILLED
 					ELSE ''
 			END as COLUMN_9_FILLED ,
 			CASE
 				WHEN COLUMN_11_FILLED <> ''
 					THEN COLUMN_10_FILLED
 					ELSE ''
 			END as COLUMN_10_FILLED ,
 			CASE
 				WHEN COLUMN_12_FILLED <> ''
 					THEN COLUMN_11_FILLED
 					ELSE ''
 			END as COLUMN_11_FILLED ,
 			CASE
 				WHEN COLUMN_13_FILLED <> ''
 					THEN COLUMN_12_FILLED
 					ELSE ''
 			END as COLUMN_12_FILLED ,
 			ROW_NUM
 		FROM
 			:CTE_3
 		ORDER BY
 			ROW_NUM
 	)
 	;
 	CTE_5 =
 	(
 		SELECT
 			ROOT_IND ,
 			CASE
 				WHEN COLUMN_0_FILLED <> ''
 					THEN 'A_'||"COLUMN_0_FILLED"
 					ELSE COLUMN_0_FILLED
 			END as "COLUMN_0_FILLED" ,
 			CASE
 				WHEN COLUMN_1_FILLED <> ''
 					THEN 'B_'||"COLUMN_1_FILLED"
 					ELSE COLUMN_1_FILLED
 			END as "COLUMN_1_FILLED" ,
 			CASE
 				WHEN COLUMN_2_FILLED <> ''
 					THEN 'C_'||"COLUMN_2_FILLED"
 					ELSE COLUMN_2_FILLED
 			END as "COLUMN_2_FILLED" ,
 			CASE
 				WHEN COLUMN_3_FILLED <> ''
 					THEN 'D_'||"COLUMN_3_FILLED"
 					ELSE COLUMN_3_FILLED
 			END as "COLUMN_3_FILLED" ,
 			CASE
 				WHEN COLUMN_4_FILLED <> ''
 					THEN 'E_'||"COLUMN_4_FILLED"
 					ELSE COLUMN_4_FILLED
 			END as "COLUMN_4_FILLED" ,
 			CASE
 				WHEN COLUMN_5_FILLED <> ''
 					THEN 'F_'||"COLUMN_5_FILLED"
 					ELSE COLUMN_5_FILLED
 			END as "COLUMN_5_FILLED" ,
 			CASE
 				WHEN COLUMN_6_FILLED <> ''
 					THEN 'G_'||"COLUMN_6_FILLED"
 					ELSE COLUMN_6_FILLED
 			END as "COLUMN_6_FILLED" ,
 			CASE
 				WHEN COLUMN_7_FILLED <> ''
 					THEN 'H_'||"COLUMN_7_FILLED"
 					ELSE COLUMN_7_FILLED
 			END as "COLUMN_7_FILLED" ,
 			CASE
 				WHEN COLUMN_8_FILLED <> ''
 					THEN 'I_'||"COLUMN_8_FILLED"
 					ELSE COLUMN_8_FILLED
 			END as "COLUMN_8_FILLED" ,
 			CASE
 				WHEN COLUMN_9_FILLED <> ''
 					THEN 'J_'||"COLUMN_9_FILLED"
 					ELSE COLUMN_9_FILLED
 			END as "COLUMN_9_FILLED" ,
 			CASE
 				WHEN COLUMN_10_FILLED <> ''
 					THEN 'K_'||"COLUMN_10_FILLED"
 					ELSE COLUMN_10_FILLED
 			END as "COLUMN_10_FILLED" ,
 			CASE
 				WHEN COLUMN_11_FILLED <> ''
 					THEN 'L_'||"COLUMN_11_FILLED"
 					ELSE COLUMN_11_FILLED
 			END as "COLUMN_11_FILLED" ,
 			CASE
 				WHEN COLUMN_12_FILLED <> ''
 					THEN 'M_'||"COLUMN_12_FILLED"
 					ELSE COLUMN_12_FILLED
 			END as "COLUMN_12_FILLED" ,
 			ROW_NUM
 		FROM
 			:CTE_4
 	)
 	;
 	CTE_6A =
 	(
 		SELECT   DISTINCT
 			ROOT_IND ,
 			PARENT   ,
 			CHILD    ,
 			ROW_NUMBER() OVER ( ORDER BY ROW_NUM) ROW_NUM
 		FROM
 			(
 				SELECT   DISTINCT
 					                ROOT_IND ,
 					COLUMN_0_FILLED PARENT   ,
 					COLUMN_1_FILLED CHILD    ,
 					ROW_NUM                  ,
 					ROW_NUMBER() OVER (PARTITION BY COLUMN_0_FILLED, COLUMN_1_FILLED) ROW_NUM1
 				FROM
 					:CTE_5
 				UNION ALL
 				SELECT   DISTINCT
 					ROOT_IND        ,
 					COLUMN_1_FILLED ,
 					COLUMN_2_FILLED ,
 					ROW_NUM         ,
 					ROW_NUMBER() OVER (PARTITION BY COLUMN_1_FILLED, COLUMN_2_FILLED) ROW_NUM1
 				FROM
 					:CTE_5
 				UNION ALL
 				SELECT   DISTINCT
 					ROOT_IND        ,
 					COLUMN_2_FILLED ,
 					COLUMN_3_FILLED ,
 					ROW_NUM         ,
 					ROW_NUMBER() OVER (PARTITION BY COLUMN_2_FILLED, COLUMN_3_FILLED) ROW_NUM1
 				FROM
 					:CTE_5
 				UNION ALL
 				SELECT   DISTINCT
 					ROOT_IND        ,
 					COLUMN_3_FILLED ,
 					COLUMN_4_FILLED ,
 					ROW_NUM         ,
 					ROW_NUMBER() OVER (PARTITION BY COLUMN_3_FILLED, COLUMN_4_FILLED) ROW_NUM1
 				FROM
 					:CTE_5
 				UNION ALL
 				SELECT   DISTINCT
 					ROOT_IND        ,
 					COLUMN_4_FILLED ,
 					COLUMN_5_FILLED ,
 					ROW_NUM         ,
 					ROW_NUMBER() OVER (PARTITION BY COLUMN_4_FILLED, COLUMN_5_FILLED) ROW_NUM1
 				FROM
 					:CTE_5
 				UNION ALL
 				SELECT   DISTINCT
 					ROOT_IND        ,
 					COLUMN_5_FILLED ,
 					COLUMN_6_FILLED ,
 					ROW_NUM         ,
 					ROW_NUMBER() OVER (PARTITION BY COLUMN_5_FILLED, COLUMN_6_FILLED) ROW_NUM1
 				FROM
 					:CTE_5
 				UNION ALL
 				SELECT   DISTINCT
 					ROOT_IND        ,
 					COLUMN_6_FILLED ,
 					COLUMN_7_FILLED ,
 					ROW_NUM         ,
 					ROW_NUMBER() OVER (PARTITION BY COLUMN_6_FILLED, COLUMN_7_FILLED) ROW_NUM1
 				FROM
 					:CTE_5
 				UNION ALL
 				SELECT   DISTINCT
 					ROOT_IND        ,
 					COLUMN_7_FILLED ,
 					COLUMN_8_FILLED ,
 					ROW_NUM         ,
 					ROW_NUMBER() OVER (PARTITION BY COLUMN_7_FILLED, COLUMN_8_FILLED) ROW_NUM1
 				FROM
 					:CTE_5
 				UNION ALL
 				SELECT   DISTINCT
 					ROOT_IND        ,
 					COLUMN_8_FILLED ,
 					COLUMN_9_FILLED ,
 					ROW_NUM         ,
 					ROW_NUMBER() OVER (PARTITION BY COLUMN_8_FILLED, COLUMN_9_FILLED) ROW_NUM1
 				FROM
 					:CTE_5
 				UNION ALL
 				SELECT   DISTINCT
 					ROOT_IND         ,
 					COLUMN_9_FILLED  ,
 					COLUMN_10_FILLED ,
 					ROW_NUM          ,
 					ROW_NUMBER() OVER (PARTITION BY COLUMN_9_FILLED, COLUMN_10_FILLED) ROW_NUM1
 				FROM
 					:CTE_5
 				UNION ALL
 				SELECT   DISTINCT
 					ROOT_IND         ,
 					COLUMN_10_FILLED ,
 					COLUMN_11_FILLED ,
 					ROW_NUM          ,
 					ROW_NUMBER() OVER (PARTITION BY COLUMN_10_FILLED, COLUMN_11_FILLED) ROW_NUM1
 				FROM
 					:CTE_5
 				UNION ALL
 				SELECT   DISTINCT
 					ROOT_IND         ,
 					COLUMN_11_FILLED ,
 					COLUMN_12_FILLED ,
 					ROW_NUM          ,
 					ROW_NUMBER() OVER (PARTITION BY COLUMN_11_FILLED, COLUMN_12_FILLED) ROW_NUM1
 				FROM
 					:CTE_5
 			)
 		WHERE
 			CHILD       <> ''
 			AND ROW_NUM1 = 1
 		ORDER BY
 			ROW_NUM
 	)
 	;
 	CTE_6 =
 	(
 		SELECT *
 		FROM
 			:CTE_6A
 		UNION ALL
 		SELECT
 			TOP 1 '0'    ROOT_IND ,
 			''           PARENT   ,
 			PARENT    as CHILD    ,
 			ROW_NUM-1 as ROW_NUM
 		FROM
 			:CTE_6A
 	)
 	;
 	CTE_7 =
 	(
 		SELECT    *
 		FROM
 			HIERARCHY (SOURCE
 			(
 				SELECT
 					CASE
 						WHEN (
 								REPLACE_REGEXPR('[[:digit:]]' IN RIGHT(CHILD, LENGTH(CHILD)-2) WITH '' OCCURRENCE ALL) = ''
 								AND LENGTH(CHILD)                                                                      = 10
 							)
 							THEN RIGHT(CHILD, LENGTH(CHILD)-2)
 						WHEN (
 								REPLACE_REGEXPR('[[:digit:]]' IN RIGHT(CHILD, LENGTH(CHILD)-2) WITH '' OCCURRENCE ALL) = 'G'
 								AND LENGTH(CHILD)                                                                      = 11
 							)
 							THEN SUBSTR(CHILD, 3, LENGTH(CHILD)-2)
 							ELSE CHILD
 					end       node_id   ,
 					PARENT as parent_id ,
 					ROW_NUM
 				FROM
 					:CTE_6
 				ORDER BY
 					ROW_NUM
 			)
 			START WHERE ROOT_IND = '0' ORPHAN ADOPT )
 		ORDER BY
 			hierarchy_rank
 	)
 	;
 	TEXT_CORE =
 	(
 		SELECT
 			CASE
 				WHEN COLUMN_0 <> ''
 					THEN 'A_'||"COLUMN_0"
 					ELSE COLUMN_0
 			END as "COLUMN_0" ,
 			CASE
 				WHEN COLUMN_1 <> ''
 					THEN 'B_'||"COLUMN_1"
 					ELSE COLUMN_1
 			END as "COLUMN_1" ,
 			CASE
 				WHEN COLUMN_2 <> ''
 					THEN 'C_'||"COLUMN_2"
 					ELSE COLUMN_2
 			END as "COLUMN_2" ,
 			CASE
 				WHEN COLUMN_3 <> ''
 					THEN 'D_'||"COLUMN_3"
 					ELSE COLUMN_3
 			END as "COLUMN_3" ,
 			CASE
 				WHEN COLUMN_4 <> ''
 					THEN 'E_'||"COLUMN_4"
 					ELSE COLUMN_4
 			END as "COLUMN_4" ,
 			CASE
 				WHEN COLUMN_5 <> ''
 					THEN 'F_'||"COLUMN_5"
 					ELSE COLUMN_5
 			END as "COLUMN_5" ,
 			CASE
 				WHEN COLUMN_6 <> ''
 					THEN 'G_'||"COLUMN_6"
 					ELSE COLUMN_6
 			END as "COLUMN_6" ,
 			CASE
 				WHEN COLUMN_7 <> ''
 					THEN 'H_'||"COLUMN_7"
 					ELSE COLUMN_7
 			END as "COLUMN_7" ,
 			CASE
 				WHEN COLUMN_8 <> ''
 					THEN 'I_'||"COLUMN_8"
 					ELSE COLUMN_8
 			END as "COLUMN_8" ,
 			CASE
 				WHEN COLUMN_9 <> ''
 					THEN 'J_'||"COLUMN_9"
 					ELSE COLUMN_9
 			END as "COLUMN_9" ,
 			CASE
 				WHEN COLUMN_10 <> ''
 					THEN 'K_'||"COLUMN_10"
 					ELSE COLUMN_10
 			END as "COLUMN_10" ,
 			CASE
 				WHEN COLUMN_11 <> ''
 					THEN 'L_'||"COLUMN_11"
 					ELSE COLUMN_11
 			END as "COLUMN_11" ,
 			CASE
 				WHEN COLUMN_12 <> ''
 					THEN 'M_'||"COLUMN_12"
 					ELSE COLUMN_12
 			END as "COLUMN_12" ,
 			CASE
 				WHEN COLUMN_13 <> ''
 					THEN 'N_'||"COLUMN_13"
 					ELSE COLUMN_13
 			END as "COLUMN_13"
 		FROM
 			"WALCZAKJ"."FI_HIER_AB_1"
 	)
 	;
 	"CTE_TEXT" =
 	(
 		SELECT
 			"COLUMN_0"  ,
 			"COLUMN_1"  ,
 			"COLUMN_2"  ,
 			"COLUMN_3"  ,
 			"COLUMN_4"  ,
 			"COLUMN_5"  ,
 			"COLUMN_6"  ,
 			"COLUMN_7"  ,
 			"COLUMN_8"  ,
 			"COLUMN_9"  ,
 			"COLUMN_10" ,
 			"COLUMN_11" ,
 			"COLUMN_12" ,
 			"COLUMN_13" ,
 			ROW_NUMBER() OVER () as ROW_NUM
 		FROM
 			:TEXT_CORE
 	)
 	;
 	TEXTS =
 	(
 		SELECT
 			CASE
 				WHEN (
 						REPLACE_REGEXPR('[[:digit:]]' IN RIGHT(COLUMN_0, LENGTH(COLUMN_0)-2) WITH '' OCCURRENCE ALL) = ''
 						AND LENGTH(COLUMN_0)                                                                         = 10
 					)
 					THEN RIGHT(COLUMN_0, LENGTH(COLUMN_0)-2)
 				WHEN (
 						REPLACE_REGEXPR('[[:digit:]]' IN RIGHT(COLUMN_0, LENGTH(COLUMN_0)-2) WITH '' OCCURRENCE ALL) = 'G'
 						AND LENGTH(COLUMN_0)                                                                         = 11
 					)
 					THEN SUBSTR(COLUMN_0, 3, LENGTH(COLUMN_0)-2)
 					ELSE COLUMN_0
 			end                                 NODE ,
 			RIGHT(COLUMN_1, LENGTH(COLUMN_1)-2) DESCRIPTION
 		FROM
 			(
 				SELECT   *
 					,
 					LAG(COLUMN_1) OVER (PARTITION BY A ORDER BY
 										ROW_NUM) as LAG
 				FROM
 					(
 						SELECT
 							'' A       ,
 							"COLUMN_0" ,
 							"COLUMN_1" ,
 							ROW_NUM
 						FROM
 							:CTE_TEXT
 						WHERE
 							"COLUMN_0" <> ''
 						UNION ALL
 						SELECT
 							'' A       ,
 							"COLUMN_1" ,
 							"COLUMN_2" ,
 							ROW_NUM
 						FROM
 							:CTE_TEXT
 						WHERE
 							"COLUMN_1" <> ''
 						UNION ALL
 						SELECT
 							'' A       ,
 							"COLUMN_2" ,
 							"COLUMN_3" ,
 							ROW_NUM
 						FROM
 							:CTE_TEXT
 						WHERE
 							"COLUMN_2" <> ''
 						UNION ALL
 						SELECT
 							'' A       ,
 							"COLUMN_3" ,
 							"COLUMN_4" ,
 							ROW_NUM
 						FROM
 							:CTE_TEXT
 						WHERE
 							"COLUMN_3" <> ''
 						UNION ALL
 						SELECT
 							'' A       ,
 							"COLUMN_4" ,
 							"COLUMN_5" ,
 							ROW_NUM
 						FROM
 							:CTE_TEXT
 						WHERE
 							"COLUMN_4" <> ''
 						UNION ALL
 						SELECT
 							'' A       ,
 							"COLUMN_5" ,
 							"COLUMN_6" ,
 							ROW_NUM
 						FROM
 							:CTE_TEXT
 						WHERE
 							"COLUMN_5" <> ''
 						UNION ALL
 						SELECT
 							'' A       ,
 							"COLUMN_6" ,
 							"COLUMN_7" ,
 							ROW_NUM
 						FROM
 							:CTE_TEXT
 						WHERE
 							"COLUMN_6" <> ''
 						UNION ALL
 						SELECT
 							'' A       ,
 							"COLUMN_7" ,
 							"COLUMN_8" ,
 							ROW_NUM
 						FROM
 							:CTE_TEXT
 						WHERE
 							"COLUMN_7" <> ''
 						UNION ALL
 						SELECT
 							'' A       ,
 							"COLUMN_8" ,
 							"COLUMN_9" ,
 							ROW_NUM
 						FROM
 							:CTE_TEXT
 						WHERE
 							"COLUMN_8" <> ''
 						UNION ALL
 						SELECT
 							'' A        ,
 							"COLUMN_9"  ,
 							"COLUMN_10" ,
 							ROW_NUM
 						FROM
 							:CTE_TEXT
 						WHERE
 							"COLUMN_9" <> ''
 						UNION ALL
 						SELECT
 							'' A        ,
 							"COLUMN_10" ,
 							"COLUMN_11" ,
 							ROW_NUM
 						FROM
 							:CTE_TEXT
 						WHERE
 							"COLUMN_10" <> ''
 						UNION ALL
 						SELECT
 							'' A        ,
 							"COLUMN_11" ,
 							"COLUMN_12" ,
 							ROW_NUM
 						FROM
 							:CTE_TEXT
 						WHERE
 							"COLUMN_11" <> ''
 						UNION ALL
 						SELECT
 							'' A        ,
 							"COLUMN_12" ,
 							"COLUMN_13" ,
 							ROW_NUM
 						FROM
 							:CTE_TEXT
 						WHERE
 							"COLUMN_12" <> ''
 					)
 			)
 		WHERE
 			COLUMN_0     <> LAG
 			AND COLUMN_1 <> ''
 		ORDER BY
 			ROW_NUM
 	)
 	;
 	CTE_8 =
 	(
 		SELECT
 			T1.PARENT_ID               ,
 			T2.DESCRIPTION PARENT_DESC ,
 			T1.NODE_ID                 ,
 			T3.DESCRIPTION NODE_DESC   ,
 			CASE
 				WHEN (
 						REPLACE_REGEXPR('[[:digit:]]' IN NODE_ID WITH '' OCCURRENCE ALL) = ''
 						AND LENGTH(NODE_ID)                                              = 8
 					)
 					OR (
 						REPLACE_REGEXPR('[[:digit:]]' IN NODE_ID WITH '' OCCURRENCE ALL) = 'G'
 						AND LENGTH(NODE_ID)                                              = 9
 					)
 					THEN 1
 					ELSE 0
 			END as G_ACCOUNT_IND    ,
 			T1.HIERARCHY_IS_CYCLE   ,
 			T1.HIERARCHY_IS_ORPHAN  ,
 			T1.HIERARCHY_LEVEL      ,
 			T1.HIERARCHY_PARENT_RANK,
 			T1.HIERARCHY_RANK       ,
 			T1.HIERARCHY_TREE_SIZE
 		FROM
 			:CTE_7 T1
 			LEFT JOIN
 				:TEXTS T2
 				ON
 					T1.PARENT_ID=T2.NODE
 			LEFT JOIN
 				:TEXTS T3
 				ON
 					T1.NODE_ID=T3.NODE
 		ORDER BY
 			HIERARCHY_RANK
 	)
 	;
 	var_out =
 	SELECT
 		"PARENT_ID"     ,
 		"PARENT_DESC"   ,
 		"NODE_ID"       ,
 		"NODE_DESC"     ,
 		"G_ACCOUNT_IND" ,
 		'CFIHIER' IOBJNM,
 		--CASE WHEN G_ACCOUNT_IND = 1 THEN 'CGACC_1' ELSE 'CFIHIER' END as IOBJNM,
 		"HIERARCHY_LEVEL"                                                                                                                                                                    ,
 		"HIERARCHY_RANK"                                                                                                                                                                     ,
 		"HIERARCHY_PARENT_RANK"                                                                                                                                                              ,
 		"HIERARCHY_TREE_SIZE"                                                                                                                                                                ,
 		SUBSTR(hier_struc,1,LOCATE_REGEXPR('~' in hier_struc OCCURRENCE 1)-1)                                                                                                    as "LVL_01"      ,
 		SUBSTR(hier_struc,LOCATE_REGEXPR('~'   in hier_struc OCCURRENCE 1)+1,LOCATE_REGEXPR('~' in hier_struc OCCURRENCE 2)-LOCATE_REGEXPR('~' in hier_struc OCCURRENCE 1)-1)    as "LVL_01_DESC" ,
 		SUBSTR(hier_struc,LOCATE_REGEXPR('~'   in hier_struc OCCURRENCE 2)+1,LOCATE_REGEXPR('~' in hier_struc OCCURRENCE 3)-LOCATE_REGEXPR('~' in hier_struc OCCURRENCE 2)-1)    as "LVL_02"      ,
 		SUBSTR(hier_struc,LOCATE_REGEXPR('~'   in hier_struc OCCURRENCE 3)+1,LOCATE_REGEXPR('~' in hier_struc OCCURRENCE 4)-LOCATE_REGEXPR('~' in hier_struc OCCURRENCE 3)-1)    as "LVL_02_DESC" ,
 		SUBSTR(hier_struc,LOCATE_REGEXPR('~'   in hier_struc OCCURRENCE 4)+1,LOCATE_REGEXPR('~' in hier_struc OCCURRENCE 5)-LOCATE_REGEXPR('~' in hier_struc OCCURRENCE 4)-1)    as "LVL_03"      ,
 		SUBSTR(hier_struc,LOCATE_REGEXPR('~'   in hier_struc OCCURRENCE 5)+1,LOCATE_REGEXPR('~' in hier_struc OCCURRENCE 6)-LOCATE_REGEXPR('~' in hier_struc OCCURRENCE 5)-1)    as "LVL_03_DESC" ,
 		SUBSTR(hier_struc,LOCATE_REGEXPR('~'   in hier_struc OCCURRENCE 6)+1,LOCATE_REGEXPR('~' in hier_struc OCCURRENCE 7)-LOCATE_REGEXPR('~' in hier_struc OCCURRENCE 6)-1)    as "LVL_04"      ,
 		SUBSTR(hier_struc,LOCATE_REGEXPR('~'   in hier_struc OCCURRENCE 7)+1,LOCATE_REGEXPR('~' in hier_struc OCCURRENCE 8)-LOCATE_REGEXPR('~' in hier_struc OCCURRENCE 7)-1)    as "LVL_04_DESC" ,
 		SUBSTR(hier_struc,LOCATE_REGEXPR('~'   in hier_struc OCCURRENCE 8)+1,LOCATE_REGEXPR('~' in hier_struc OCCURRENCE 9)-LOCATE_REGEXPR('~' in hier_struc OCCURRENCE 8)-1)    as "LVL_05"      ,
 		SUBSTR(hier_struc,LOCATE_REGEXPR('~'   in hier_struc OCCURRENCE 9)+1,LOCATE_REGEXPR('~' in hier_struc OCCURRENCE 10)-LOCATE_REGEXPR('~' in hier_struc OCCURRENCE 9)-1)   as "LVL_05_DESC" ,
 		SUBSTR(hier_struc,LOCATE_REGEXPR('~'   in hier_struc OCCURRENCE 10)+1,LOCATE_REGEXPR('~' in hier_struc OCCURRENCE 11)-LOCATE_REGEXPR('~' in hier_struc OCCURRENCE 10)-1) as "LVL_06"      ,
 		SUBSTR(hier_struc,LOCATE_REGEXPR('~'   in hier_struc OCCURRENCE 11)+1,LOCATE_REGEXPR('~' in hier_struc OCCURRENCE 12)-LOCATE_REGEXPR('~' in hier_struc OCCURRENCE 11)-1) as "LVL_06_DESC" ,
 		SUBSTR(hier_struc,LOCATE_REGEXPR('~'   in hier_struc OCCURRENCE 12)+1,LOCATE_REGEXPR('~' in hier_struc OCCURRENCE 13)-LOCATE_REGEXPR('~' in hier_struc OCCURRENCE 12)-1) as "LVL_07"      ,
 		SUBSTR(hier_struc,LOCATE_REGEXPR('~'   in hier_struc OCCURRENCE 13)+1,LOCATE_REGEXPR('~' in hier_struc OCCURRENCE 14)-LOCATE_REGEXPR('~' in hier_struc OCCURRENCE 13)-1) as "LVL_07_DESC" ,
 		SUBSTR(hier_struc,LOCATE_REGEXPR('~'   in hier_struc OCCURRENCE 14)+1,LOCATE_REGEXPR('~' in hier_struc OCCURRENCE 15)-LOCATE_REGEXPR('~' in hier_struc OCCURRENCE 14)-1) as "LVL_08"      ,
 		SUBSTR(hier_struc,LOCATE_REGEXPR('~'   in hier_struc OCCURRENCE 15)+1,LOCATE_REGEXPR('~' in hier_struc OCCURRENCE 16)-LOCATE_REGEXPR('~' in hier_struc OCCURRENCE 15)-1) as "LVL_08_DESC" ,
 		SUBSTR(hier_struc,LOCATE_REGEXPR('~'   in hier_struc OCCURRENCE 16)+1,LOCATE_REGEXPR('~' in hier_struc OCCURRENCE 17)-LOCATE_REGEXPR('~' in hier_struc OCCURRENCE 16)-1) as "LVL_09"      ,
 		SUBSTR(hier_struc,LOCATE_REGEXPR('~'   in hier_struc OCCURRENCE 17)+1,LOCATE_REGEXPR('~' in hier_struc OCCURRENCE 18)-LOCATE_REGEXPR('~' in hier_struc OCCURRENCE 17)-1) as "LVL_09_DESC" ,
 		SUBSTR(hier_struc,LOCATE_REGEXPR('~'   in hier_struc OCCURRENCE 18)+1,LOCATE_REGEXPR('~' in hier_struc OCCURRENCE 19)-LOCATE_REGEXPR('~' in hier_struc OCCURRENCE 18)-1) as "LVL_10"     ,
 		SUBSTR(hier_struc,LOCATE_REGEXPR('~'   in hier_struc OCCURRENCE 19)+1,LOCATE_REGEXPR('~' in hier_struc OCCURRENCE 20)-LOCATE_REGEXPR('~' in hier_struc OCCURRENCE 19)-1) as "LVL_10_DESC",
 		SUBSTR(hier_struc,LOCATE_REGEXPR('~'   in hier_struc OCCURRENCE 20)+1,LOCATE_REGEXPR('~' in hier_struc OCCURRENCE 21)-LOCATE_REGEXPR('~' in hier_struc OCCURRENCE 20)-1) as "LVL_11"     ,
 		SUBSTR(hier_struc,LOCATE_REGEXPR('~'   in hier_struc OCCURRENCE 21)+1,LOCATE_REGEXPR('~' in hier_struc OCCURRENCE 22)-LOCATE_REGEXPR('~' in hier_struc OCCURRENCE 21)-1) as "LVL_11_DESC",
 		SUBSTR(hier_struc,LOCATE_REGEXPR('~'   in hier_struc OCCURRENCE 22)+1,LOCATE_REGEXPR('~' in hier_struc OCCURRENCE 23)-LOCATE_REGEXPR('~' in hier_struc OCCURRENCE 22)-1) as "LVL_12"     ,
 		SUBSTR(hier_struc,LOCATE_REGEXPR('~'   in hier_struc OCCURRENCE 23)+1,LOCATE_REGEXPR('~' in hier_struc OCCURRENCE 24)-LOCATE_REGEXPR('~' in hier_struc OCCURRENCE 23)-1) as "LVL_12_DESC" 
	from
 		(
 			select *
 			from
 				hierarchy_ancestors_aggregate ( source :CTE_8 measures ( string_agg(NODE_ID||'~'||NODE_DESC, '~') as hier_struc ) ) --where hierarchy_tree_size = 1
 			order by
 				HIERARCHY_RANK
 		)
 	;
 
 END
 /********* End Procedure Script ************/
 
