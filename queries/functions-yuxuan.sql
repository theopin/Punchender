/* ------------------------ */
-- SELECT email, name FROM Users WHERE email IN (
-- SELECT * FROM
--     /* Find email of superbackers based on the two conditions */
--     /* C1: funded at least 5 successful projects with at least 3 different ptypes */
--     (SELECT * FROM (SELECT B.email FROM Backs B INNER JOIN Projects P ON B.id = P.id WHERE ('2022-04-01' - P.deadline <= 30) GROUP BY B.email HAVING COUNT(B.email) >= 5 AND COUNT(DISTINCT P.ptype) >= 3) AS c1
--     UNION
--     /* C2: funded >= $1500 on successful projects without any refund requests */
--     SELECT * FROM (SELECT B.email FROM Backs B INNER JOIN Projects P ON B.id = P.id WHERE ('2022-04-01' - P.deadline <= 30) AND (B.request IS NULL) GROUP BY B.email HAVING SUM(B.amount) >= 1500) AS c2
--     ) AS sb) ORDER BY email DESC;
/* ----- FUNCTIONS    ----- */

/* Function #1  */
CREATE OR REPLACE FUNCTION find_superbackers(today DATE) RETURNS TABLE(email TEXT, name TEXT) AS $$ -- add declaration here
-- superbacker: must be verified AND
-- backed at least 5 successful projs within 30 days of deadline OR funded $1500 on successful projs within 30 days of deadline without requesting refund
-- Question: need to check for entry in Refunds table if already check for Backs.request is NULL? i.e. does not having refund requests mean that there wont be accepted/rejected refunds requested?
#variable_conflict use_column
DECLARE
    
BEGIN -- your code here
    RETURN QUERY
    SELECT email, name
    FROM Users
    WHERE email IN 
    (SELECT * FROM
    /* Find email of superbackers based on the two conditions */
    /* C1: funded at least 5 successful projects with at least 3 different ptypes */
    (SELECT * FROM (SELECT B.email FROM Backs B INNER JOIN Projects P ON B.id = P.id WHERE (today - P.deadline <= 30) GROUP BY B.email HAVING COUNT(B.email) >= 5 AND COUNT(DISTINCT P.ptype) >= 3) AS c1
    UNION
    /* C2: funded >= $1500 on successful projects without any refund requests */
    SELECT * FROM (SELECT B.email FROM Backs B INNER JOIN Projects P ON B.id = P.id WHERE (today - P.deadline <= 30) AND (B.request IS NULL) GROUP BY B.email HAVING SUM(B.amount) >= 1500) AS c2
    ) AS sb)
    ORDER BY email;
END;
$$ LANGUAGE plpgsql;

/* Function #2  */
-- success metric: ratio of funded $/ goal $
-- if tie, later deadline = more successful
-- if tie, smaller pid = more successful
CREATE OR REPLACE FUNCTION find_top_success(n INT, today DATE, ptype TEXT) RETURNS TABLE(
    id INT,
    name TEXT,
    email TEXT,
    amount NUMERIC
) AS $$
SELECT pr.id, pr.name, pr.email, (SELECT SUM(amount) FROM Backs B WHERE B.id = pr.id) AS amount
    FROM
    (SELECT DISTINCT P.id, P.name, P.email, P.ptype, P.deadline, (SELECT SUM(amount) FROM Backs B WHERE B.id = P.id)/P.goal AS ratio
    FROM Projects P INNER JOIN Backs B ON P.id = B.id) AS pr
    WHERE ptype = pr.ptype 
    AND pr.deadline < today 
    AND ratio > 0
    ORDER BY ratio DESC, deadline DESC, id 
    LIMIT n
$$ LANGUAGE sql;

/* Function #3  */
CREATE OR REPLACE FUNCTION find_top_popular(n INT, today DATE, ptype TEXT) RETURNS TABLE(
    id INT,
    name TEXT,
    email TEXT,
    days INT
) AS $$
BEGIN -- your code here
    RETURN QUERY SELECT * FROM find_popular(today, ptype) 
    ORDER BY days, id
    LIMIT n;
END;

$$ LANGUAGE plpgsql;

/* Helper for Function #3  */
-- popularity metric: how fast the project reach their funding goal counted as number of days since it was created
-- smaller is better
CREATE OR REPLACE FUNCTION find_popular(today DATE, ptype TEXT) RETURNS TABLE(
    id INT,
    name TEXT,
    email TEXT,
    days INT
) AS $$ -- add declaration here
DECLARE
    curs CURSOR FOR (SELECT DISTINCT P.id, P.name, P.email, P.ptype, P.created, P.deadline, P.goal, B.backing, B.amount
    FROM Projects P INNER JOIN Backs B ON P.id = B.id WHERE (SELECT SUM(amount) FROM Backs B WHERE B.id = P.id) >= P.goal AND P.created <= today GROUP BY P.id, B.backing, B.amount);
    r RECORD;
    funded INT := 0;
    project_goal NUMERIC := 0;
BEGIN -- your code here
-- Find no. of days it took to fund a project successfully
-- For each backing date, check if total funds reached project goal
OPEN curs;
LOOP
    FETCH curs INTO r;
    EXIT WHEN NOT FOUND;
    funded := funded + r.amount;
    project_goal := r.goal;
    /* Check if project has been funded successfully yet, and if there are already n records in output table */
    IF funded >= project_goal AND r.ptype = ptype THEN id := r.id; name := r.name; email := r.email; days := r.backing - r.created; RETURN NEXT;
    ELSE CONTINUE;
    END IF;
    funded := 0;
    project_goal := 0;
END LOOP;
CLOSE curs;
END;

$$ LANGUAGE plpgsql;
/* ------------------------ */