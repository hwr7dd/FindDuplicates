------------------------------------------------------------
--Drops temp tables from previous runs (if applicable)
-----------------------------------------------------------

IF OBJECT_ID(N'tempdb..#keys') IS NOT NULL
DROP TABLE #keys;
IF OBJECT_ID(N'tempdb..#tables') IS NOT NULL
DROP TABLE #tables;
IF OBJECT_ID(N'tempdb..#final') IS NOT NULL
DROP TABLE #final;
-----------------------------------------------------------------------------
--@schema is the schema being looped through. 
---------------------------------------------------------------------------

DECLARE @schema nvarchar(max);
SET @schema ='prc'

------------------------------------------------------------------------------------------------------------------------
--#keys holds the table name as well as a column containing all the columns used as a primary key
--The primarykey column can hold one value or many comma delimited values depending on what is used for the primary key
------------------------------------------------------------------------------------------------------------------------

CREATE TABLE #keys(tablename NVARCHAR(50),
                              primarykey NVARCHAR(400))
INSERT INTO #keys
SELECT p.*
FROM
  (SELECT t.name as 'tablename',STRING_AGG(QUOTENAME(c.name), ', ') AS 'grouped'
   FROM sys.tables t
   JOIN sys.schemas s ON s.schema_id = t.schema_id
   JOIN sys.indexes i ON i.object_id = t.object_id
   JOIN sys.partitions p 
ON t.[object_id] = p.[object_id]
   JOIN sys.index_columns ic ON ic.object_id = i.object_id
   JOIN sys.columns c ON c.column_id = ic.column_id
   AND c.object_id = t.object_id
   WHERE ic.index_id = i.index_id
     AND ic.object_id = i.object_id
     AND ic.is_included_column = 0
     AND i.is_primary_key = 1
	 AND p.rows>1
     AND s.name = @schema
   GROUP BY t.name) p

------------------------------------------------------------
--Final is used to store the results of the procedure.
------------------------------------------------------------------------

CREATE TABLE #final(tablename NVARCHAR(400),duplicates NVARCHAR(400), jobruntime nvarchar(400))
--------------------------------------------------------------
--@curtable is the current table name being used in the while loop below
-------------------------------------------------------------------------

DECLARE @curtable nvarchar(max);

-----------------------------------------------------------------------------
--@curkey is the current primary key column/s being used in the while loop below
---------------------------------------------------------------------------

DECLARE @curkey nvarchar(max);


---------------------------------------------------------------------------------
--@statement holds the query that uses row_number to find duplicate primary keys
-------------------------------------------------------------------------------

DECLARE @statement nvarchar(max);

WHILE (SELECT COUNT(*) FROM #keys) > 1 
BEGIN
 SET @curtable = (SELECT TOP 1 tablename from #keys order by tablename DESC)
 SET @curkey=(SELECT TOP 1 primarykey from #keys order by tablename DESC)
 SET @statement = 'INSERT INTO #final SELECT '''+@curtable+''',MAX(k.duplicates)-1,GETUTCDATE()
FROM (SELECT ROW_NUMBER() OVER( PARTITION BY '+@curkey+' ORDER BY '+@curkey+' DESC) as ''duplicates'' from '+@schema+'.'+@curtable+')k
'
 exec(@statement)
 print(@statement)
 DELETE FROM #keys where #keys.tablename = @curtable
END 
INSERT INTO intgr_stg.sp_duplicate_key_check 
SELECT * FROM #final