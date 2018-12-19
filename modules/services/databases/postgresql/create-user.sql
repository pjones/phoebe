DO
$body$
BEGIN
  IF NOT EXISTS (
    SELECT
      FROM pg_catalog.pg_roles
     WHERE rolname = '@@USERNAME@@') THEN

    CREATE ROLE @@USERNAME@@ LOGIN ENCRYPTED PASSWORD '@@PASSWORD@@';
  END IF;
END
$body$;
