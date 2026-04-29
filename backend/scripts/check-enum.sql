SELECT typname, enumlabel 
FROM pg_type t 
JOIN pg_enum e ON t.oid = e.enumtypid 
WHERE typname LIKE '%coverage%' OR typname LIKE '%status%'
ORDER BY typname, enumsortorder;
