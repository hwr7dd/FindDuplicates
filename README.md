# FindDuplicates

This script is deceptively simple. Use case was that Azure synapse wasn't properly enforcing primary key constraints so we needed a stored procedure to loop through the tables to find duplicates. This stored procedure uses dynamic SQL, loops, sub queries and other more difficult SQL operations.
