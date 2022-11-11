/* ----- TRIGGERS     ----- */

-- Trigger 1: Users must be backers, creators, or both. In other words, there must not be any users that are neither backers nor creators.

CREATE OR REPLACE FUNCTION check_existence_backers_creators () 
RETURNS TRIGGER AS $$ 

DECLARE  
	count_backers INT;
  count_creators INT;

BEGIN

    SELECT COUNT(*) INTO count_backers
    FROM Backers
    WHERE email = NEW.email;

    SELECT COUNT(*) INTO count_creators
    FROM Creators
    WHERE email = NEW.email;
    
    IF (count_backers = 0 AND count_creators = 0) THEN
      RAISE EXCEPTION 'No Entries in Backers or Creators found for %. Rollback!', NEW.email;
      RETURN NULL;
    ELSE
      RETURN NEW;
    END IF;

END;


$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS backers_creators_existence ON Users;

CREATE CONSTRAINT TRIGGER backers_creators_existence
AFTER INSERT ON Users
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION check_existence_backers_creators();


-- Trigger 2: Backers must pledge an amount greater than or equal to the minimum amount for the reward level.

CREATE OR REPLACE FUNCTION check_pledge_amt () 
RETURNS TRIGGER AS $$ 

DECLARE  
	reward_min_amt NUMERIC;

BEGIN

    SELECT min_amt INTO reward_min_amt
    FROM REWARDS
    WHERE name = NEW.name AND id = NEW.id;
    
    IF (NEW.amount < reward_min_amt) THEN
      RETURN NULL;
    ELSE
      RETURN NEW;
    END IF;

END;


$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS valid_backs_pledge ON Backs;

CREATE TRIGGER valid_backs_pledge
BEFORE INSERT ON Backs
FOR EACH ROW EXECUTE FUNCTION check_pledge_amt();


-- Trigger 3: Projects must have at least one reward level. In other words, there must not be any projects without any reward level.

CREATE OR REPLACE FUNCTION check_existence_rewards () 
RETURNS TRIGGER AS $$ 

DECLARE  
	count_rewards INT;
BEGIN

    SELECT COUNT(*) INTO count_rewards
    FROM Rewards
    WHERE id = NEW.id;

    
    IF (count_rewards = 0) THEN
      RAISE EXCEPTION 'No Rewards found. Rollback!';
      RETURN NULL;
    ELSE
      RETURN NEW;
    END IF;

END;

$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS rewards_existence ON Projects;

CREATE CONSTRAINT TRIGGER rewards_existence
AFTER INSERT ON Projects
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION check_existence_rewards();

-- Trigger 4: Enforce the constraint that refund can only be approved for refunds requested within 90 days of deadline.
-- Trigger 4: Also enforce the constraint that refund not requested cannot be approved/rejected.

CREATE OR REPLACE FUNCTION reject_refunds_91_days_after_deadline ()
RETURNS TRIGGER AS $$ 

DECLARE  
    deadline DATE;

BEGIN

    SELECT Projects.deadline INTO deadline
    FROM Backs, Rewards, Projects
    WHERE Backs.email = NEW.email AND Backs.id = NEW.id AND Backs.name = Rewards.name AND Backs.id = Rewards.id AND Rewards.id = Projects.id;
    
    IF (DATEDIFF(day, NEW.date, deadline) > 90) THEN
        NEW.accepted:=false
    END IF;
    RETURN NEW;

END;


$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER refund_request_auto_rejection
BEFORE UPDATE ON Refunds
FOR EACH ROW EXECUTE FUNCTION reject_refunds_91_days_after_deadline();

CREATE OR REPLACE FUNCTION remove_status_on_refund_request()
RETURNS TRIGGER AS $$

BEGIN

    NEW.accepted:=NULL
    RETURN NEW;

END;

$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER no_status_on_refund_request
BEFORE INSERT ON Refunds
FOR EACH ROW EXECUTE FUNCTION remove_status_on_refund_request();


-- Trigger 5: Enforce the constraint that backers back before deadline.

CREATE OR REPLACE FUNCTION remove_back_after_deadline()
RETURNS TRIGGER AS $$ 

DECLARE  
	deadline DATE;
	creation_date DATE;
BEGIN
    SELECT Projects.deadline, Projects.created INTO deadline, creation_date
    FROM Projects, Rewards
    WHERE Rewards.name = NEW.name AND Rewards.id = NEW.id AND Projects.id = Rewards.id;

    IF (NEW.backing > deadline) OR (NEW.backing < creation_date) 
    THEN
      RETURN NULL; 
    ELSE
      RETURN NEW;
    END IF;

END;


$$ LANGUAGE plpgsql;

CREATE TRIGGER back_before_deadline
BEFORE INSERT ON Backs
FOR EACH ROW EXECUTE FUNCTION remove_back_after_deadline();


-- Trigger 6: Enforce the constraint that refund can only be made for successful projects.

CREATE OR REPLACE FUNCTION check_refund_validity()
RETURNS TRIGGER AS $$ 

DECLARE  
	deadline DATE;
	pledged_amt NUMERIC;
	funding_goal NUMERIC;
BEGIN

    SELECT Projects.deadline INTO deadline
    FROM Projects, Rewards
    WHERE Rewards.name = NEW.name AND Rewards.id = NEW.id AND Projects.id = Rewards.id;

    SELECT Projects.goal INTO funding_goal
    FROM Projects, Rewards
    WHERE Rewards.name = NEW.name AND Rewards.id = NEW.id AND Projects.id = Rewards.id;

    SELECT SUM(amount) INTO pledged_amt
    FROM Backs
    WHERE id = NEW.id AND name = NEW.name;

    
    IF (pledged_amt >= funding_goal AND NEW.request > deadline) THEN
      RETURN NEW;
    ELSE
      RETURN NULL;
    END IF;

END;

$$ LANGUAGE plpgsql;

CREATE TRIGGER refund_successful_projects
BEFORE UPDATE ON Backs
FOR EACH ROW EXECUTE FUNCTION check_refund_validity();


/* ------------------------ */

/* ----- PROECEDURES  ----- */
/* Procedure #1 */
/* 1. Write a procedure to add a user which may be a backer, a creator, or both. */
CREATE OR REPLACE PROCEDURE add_user(
    email TEXT,
    name TEXT,
    cc1 TEXT,
    cc2 TEXT,
    street TEXT,
    num TEXT,
    zip TEXT,
    country TEXT,
    kind TEXT
) AS $$ 
BEGIN 
    INSERT INTO Users -- Project specs allows us to assume inputs are valid
    VALUES ( email, name, cc1, cc2);

    IF kind in ('BACKER', 'BOTH')  THEN
        INSERT INTO Backers
        VALUES ( email, street, num, zip, country);
        END IF;

    IF kind in ('CREATOR', 'BOTH')  THEN
        INSERT INTO Creators
        VALUES ( email, country);
    END IF;
END; 

$$ LANGUAGE plpgsql;


/* Procedure #2 */
/* Write a procedure to add a project and the corresponding reward levels */
CREATE OR REPLACE PROCEDURE add_project(
    id INT,
    email TEXT,
    ptype TEXT,
    created DATE,
    name TEXT,
    deadline DATE,
    goal NUMERIC,
    names TEXT [],
    amounts NUMERIC []
) AS $$ 
BEGIN 
    INSERT INTO Projects
    values (id, email, ptype, created, name, deadline, goal);

    FOR i IN 1 .. array_upper(names, 1) 
    LOOP
        INSERT INTO Rewards
        values (names[i], id, amounts[i]);
    END LOOP;
END;
$$ LANGUAGE plpgsql;


/* Procedure #3 */
/*
Write a procedure to help an employee with id eid automatically reject
all refund request where the date of the request is more than 90 days from
the deadline of the project. 
*/

CREATE OR REPLACE PROCEDURE auto_reject(eid INT, today DATE) AS $$ 
DECLARE
backing RECORD;
proj_deadline DATE;
BEGIN 
    FOR backing IN SELECT * FROM Backs
    LOOP
        SELECT deadline INTO proj_deadline FROM Projects p where p.id = backing.id;
        /* IS A REQUEST (Not processed yet)*/
        IF backing.request IS NOT NULL 
        AND NOT EXISTS (
            SELECT * 
            FROM REFUNDS r 
            WHERE r.email = backing.email 
            AND r.pid = backing.id
            ) 
        /* After 90 days from deadline*/
        AND Abs(backing.request - proj_deadline) > 90
        THEN 
            INSERT INTO Refunds
            values(backing.email, backing.id, eid, today, FALSE);
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;


/* ------------------------ */

/* ----- FUNCTIONS    ----- */
/* Helper function to check whether a project is successful */
CREATE OR REPLACE FUNCTION is_successful_proj(p_id INT, today DATE) RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM Projects P
        WHERE P.id = p_id
            AND (SELECT SUM(amount) FROM Backs B WHERE B.id = P.id) >= P.goal -- Total pledged exceeds funding goal
            -- DEADLINE HAS PASSED
            AND p.deadline < today
    );
END
$$ LANGUAGE plpgsql;

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
    WHERE email IN (SELECT email FROM Verifies) AND email IN
    /*today Find email of superbackers based on the two conditions */
    /* C1: funded at least 5 successful projects with at least 3 different ptypes */
    (SELECT * FROM (
        SELECT B.email 
        FROM Backs B INNER JOIN Projects P 
        ON B.id = P.id 
        WHERE (today - P.deadline <= 30)  -- Deadline within 30 days of given date
            AND is_successful_proj(P.id, today) -- Project is successful
        GROUP BY B.email 
        HAVING COUNT(B.email) >= 5  -- At least 5 projects
        AND COUNT(DISTINCT P.ptype) >= 3) -- At least 3 different project types
        AS c1 
    UNION
    /* C2: funded >= $1500 on successful projects without any refund requests */
    SELECT * FROM (
        SELECT B.email 
        FROM Backs B 
        WHERE 
            NOT EXISTS (SELECT * FROM Backs B2 WHERE B2.email = B.email AND B2.request - today <= 30)   -- Backer must not have any refund request, accepted/rejected refunds in the last 30 days
            AND 1500 <= ( -- Total funding at least 1500
                 SELECT SUM(B2.amount) -- Actual total funding from this one user in the last 30 days on any succesful projects
                 FROM Backs B2 INNER JOIN Projects P
                 ON B2.id = P.id 
                 WHERE B2.email = B.email
                    AND is_successful_proj(P.id, today) -- Project is successful
                    AND today - P.deadline <= 30 -- Deadline of the project within 30 days of given date (in the past)
                 ) 
        ) AS c2
    )
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
    (SELECT DISTINCT P.id, P.name, P.email, P.ptype AS t_ptype, P.deadline, (SELECT SUM(amount) FROM Backs B WHERE B.id = P.id)/P.goal AS ratio
    FROM Projects P INNER JOIN Backs B ON P.id = B.id WHERE is_successful_proj(P.id)) AS pr
    WHERE pr.deadline < today
    AND pr.t_ptype = ptype
    ORDER BY ratio DESC, deadline DESC, id
    LIMIT n;
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
    -- Projects where we have execeeded the goal at some point, grouped by id backing and amount
    FROM Projects P INNER JOIN Backs B ON P.id = B.id WHERE (SELECT SUM(amount) FROM Backs B WHERE B.id = P.id) >= P.goal AND P.created <= today GROUP BY P.id, B.backing, B.amount); 
    r RECORD;
    funded NUMERIC := 0;
    project_goal NUMERIC := 0;
    look_for_next BOOLEAN := FALSE;
    prev_proj_id INT := 0;
BEGIN -- your code here
-- Find no. of days it took to fund a project successfully
-- For each backing date, check if total funds reached project goal
OPEN curs;
LOOP
    FETCH curs INTO r;
    EXIT WHEN NOT FOUND;

    IF look_for_next = TRUE THEN 
        IF  r.id <> prev_proj_id THEN
        look_for_next := FALSE;
        ELSE CONTINUE; 
        END IF;
    END IF;

    prev_proj_id = r.id;
    funded := funded + r.amount;
    project_goal := r.goal;
    /* Check if project has been funded successfully yet */
    IF funded >= project_goal AND r.ptype = ptype 
        THEN 
        id := r.id; name := r.name; email := r.email; days := r.backing - r.created; look_for_next := TRUE;
        RETURN NEXT;
    ELSE CONTINUE;
    END IF;
    funded := 0;
    project_goal := 0;
END LOOP;
CLOSE curs;
END;

$$ LANGUAGE plpgsql;
/* ------------------------ */