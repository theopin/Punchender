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
BEGIN -- Begin Transaction, auto rolls back if exception thrown
    if kind = 'BACKER' THEN
        INSERT INTO Users
        VALUES ( email, name, cc1, cc2);

        INSERT INTO Backers
        VALUES ( email, street, num, zip, country);
    ELSIF kind = 'CREATOR' THEN
        INSERT INTO Users
        VALUES ( email, name, cc1, cc2);

        INSERT INTO Creators
        VALUES ( email, country);
    ELSIF kind = 'BOTH' THEN -- TODO is there a way to shorten code
        INSERT INTO Users
        VALUES ( email, name, cc1, cc2);

        INSERT INTO Creators
        VALUES ( email, country);

        INSERT INTO Backers
        VALUES ( email, street, num, zip, country);
    END IF;
END; -- Commits transaction only if everything above causes no errors

$$ LANGUAGE plpgsql;


/* Procedure #2 */
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
) AS $$ -- add declaration here
BEGIN -- your code here
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
CREATE OR REPLACE PROCEDURE auto_reject(eid INT, today DATE) AS $$ -- add declaration here
DECLARE
backing RECORD;
proj_deadline DATE;
BEGIN -- your code here
    FOR backing IN SELECT * FROM Backs
    LOOP
        SELECT deadline INTO proj_deadline FROM Projects p where p.id = backing.id;
        /* IS A REQUEST */
        IF backing.request IS NOT NULL AND NOT EXISTS (SELECT * FROM REFUNDS r WHERE r.email = backing.email AND r.pid = backing.id) THEN 
            IF Abs(backing.request - proj_deadline) > 90 THEN 
                INSERT INTO Refunds
                values(backing.email, backing.id, eid, today, FALSE);
            END IF;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;


/* TESTING ------------------------------------------------------------------------ */
/* helper procedures*/
CREATE OR REPLACE PROCEDURE print_user_count() AS $$ 
DECLARE 
-- user_count INT := select COUNT(*) FROM Users;
BEGIN 
    RAISE NOTICE  'User count: %', COUNT(*) cnt FROM Users;
    RAISE NOTICE  'Backer count: %', COUNT(*) cnt FROM Backers;
    RAISE NOTICE  'Creator count: %', COUNT(*) cnt FROM Creators;
END; 
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE print_users() AS $$ 
DECLARE 
items record;
-- user_count INT := select COUNT(*) FROM Users;
BEGIN 
    FOR items IN SELECT * FROM Users LOOP
    RAISE NOTICE '%', to_json(items);
    END LOOP;
END; 
$$ LANGUAGE plpgsql;


CREATE OR REPLACE PROCEDURE print_backers() AS $$ 
DECLARE 
items record;
-- user_count INT := select COUNT(*) FROM Users;
BEGIN 
    FOR items IN SELECT * FROM Backers LOOP
    RAISE NOTICE '%', to_json(items);
    END LOOP;
END; 
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE print_creators() AS $$ 
DECLARE 
items record;
-- user_count INT := select COUNT(*) FROM Users;
BEGIN 
    FOR items IN SELECT * FROM Creators LOOP
    RAISE NOTICE '%', to_json(items);
    END LOOP;
END; 
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE print_proj() AS $$ 
DECLARE 
items record;
-- user_count INT := select COUNT(*) FROM Users;
BEGIN 
    FOR items IN SELECT * FROM Projects LOOP
    RAISE NOTICE '%', to_json(items);
    END LOOP;
END; 
$$ LANGUAGE plpgsql;


CREATE OR REPLACE PROCEDURE print_refunds() AS $$ 
DECLARE 
items record;
-- user_count INT := select COUNT(*) FROM Users;
BEGIN 
    RAISE NOTICE  'Reward count: %', COUNT(*) cnt FROM Rewards;
    FOR items IN SELECT * FROM Refunds LOOP
    RAISE NOTICE '%', to_json(items);
    END LOOP;
END; 
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE print_rewards() AS $$ 
DECLARE 
items record;
-- user_count INT := select COUNT(*) FROM Users;
BEGIN 
    FOR items IN SELECT * FROM Rewards LOOP
    RAISE NOTICE '%', to_json(items);
    END LOOP;
END; 
$$ LANGUAGE plpgsql;

/* Procedure #1  ------------------------------------------------------------------------ */
/* HAPPY CASES 
Exepected OUT

NOTICE:  User count: 101
NOTICE:  Backer count: 42
NOTICE:  Creator count: 44
CALL
CALL
NOTICE:  User count: 102
NOTICE:  Backer count: 43
NOTICE:  Creator count: 44
CALL
CALL
NOTICE:  User count: 103
NOTICE:  Backer count: 43
NOTICE:  Creator count: 45
*/
\i import.sql;
call add_user ( 'abnermtj@live.com.sg', 'Tolentino Abner Jr Morales','123123123',NULL,'Pasir Ris','123123','512022','Singapore', 'BOTH');
call print_user_count();
call print_users();
call print_backers();
call print_creators();
call add_user ( 'Notabnermtj@live.com.sg', 'NOT Tolentino Abner Jr Morales','123123123',NULL,'Pasir Ris','123123','512022','Singapore', 'BACKER');
call print_user_count();
call print_users();
call add_user ( 'yuthuan@live.com.sg', 'YuXuan','123123123','2','Pasir Ris','123123','512022','Singapore', 'CREATOR');
call print_user_count();
call print_users();

/* FAIL CASES 
Expected OUT:

ERROR for the first
NOTICE:  User count: 103
NOTICE:  Backer count: 43
NOTICE:  Creator count: 45
*/
call add_user ( 'poop@live.com.sg', 'poop',12,NULL,'Pasir Ris',123123,512022,'Singapore', 'BOTH');
call print_user_count();
call add_user ( 'theo@live.com.sg', 'Theo pinto','123123123','1232123','Pasir Ris','123123','512022','Singapore', 'BACKERS');
call print_user_count();
call add_user ( 'ryan@live.com.sg', 'Ryan','12',NULL,'Pasir Ris','123123','512022','Singapore', 'NOTVALIDKEYWORD');
call print_user_count();



/* Procedure #2  ------------------------------------------------------------------------ */
/* HAPPY CASES 
Exepected OUT

Insertion into Rewards and Projects
*/
\i import.sql;

-- call print_proj();
call print_rewards();
call add_project(2, 'lshutery@vistaprint.com', 'Art', '4-25-2022', 'Best Project', '4-30-2022', 1000.23, ARRAY['Bronze', 'Silver'], ARRAY[5, 10.5]);
-- call print_proj();
call print_rewards();

/* FAIL CASES 
Expected OUT:

No changes to Projects or Rewards
*/
call print_proj();
-- call print_rewards();
call add_project(2, 'lshutery@vistaprint.com', 'Art', '4-25-2022', 'Best Project', '4-30-2022', 1000.23, ARRAY['Bronze', 'Silver'], ARRAY[5]);
call print_proj();
-- call print_rewards();

/* Procedure #2  ------------------------------------------------------------------------ */
/* HAPPY CASES 
Exepected OUT
*/
\i import.sql;

-- call print_proj();
call print_rewards();
call add_project(2, 'lshutery@vistaprint.com', 'Art', '4-25-2022', 'Best Project', '4-30-2022', 1000.23, ARRAY['Bronze', 'Silver'], ARRAY[5, 10.5]);
-- call print_proj();
call print_rewards();

/* FAIL CASES 
Expected OUT:
*/
call print_proj();
-- call print_rewards();
call add_project(2, 'lshutery@vistaprint.com', 'Art', '4-25-2022', 'Best Project', '4-30-2022', 1000.23, ARRAY['Bronze', 'Silver'], ARRAY[5]);
call print_proj();
-- call print_rewards();

/* Procedure #3  ------------------------------------------------------------------------ */
/* HAPPY CASES 
Exepected OUT

INSERT
283810751
*/
\i import.sql;

--SELECT b.id, b.email, b.request, p.deadline, Abs(b.request - p.deadline) as distance FROM Backs b, Projects p where b.id = p.id AND Abs(b.request - p.deadline) > 90 AND NOT EXISTS (SELECT * FROM REFUNDS r WHERE r.email = b.email AND r.pid = b.id);
--SELECT * FROM REFUNDS;
delete from refunds *;
delete from backs *;
-- DEADLINE for pid = 20 IS 2023-01-07
INSERT INTO Backs VALUES ( 'ddegowe2r@wiley.com','Oldsmobile',20,	'9/30/2022','1/7/2023',337.5);

-- Expect NO change!
call print_refunds();
call auto_reject(362581169, '10/29/2022');
call print_refunds();

update backs set request = '4/7/2023';
-- Expect No change +90 days
call print_refunds();
call auto_reject(354707606, '6/26/2023');
call print_refunds();

update backs set request = '10/9/2022';
-- Expect No change -90 days
call print_refunds();
call auto_reject(354707606, '10/9/2022');
call print_refunds();

update backs set request = '4/8/2023';
-- Expect add +91 days
call print_refunds();
call auto_reject(283810751, '6/26/2023');
call print_refunds();
update backs set request = '4/8/2023';

delete from refunds *;
delete from backs *;
-- DEADLINE for pid = 20 IS 2023-01-07
INSERT INTO Backs VALUES ( 'ddegowe2r@wiley.com','Oldsmobile',20,	'9/30/2022','1/7/2023',337.5);

-- Expect add -91 days
update backs set request = '10/8/2022';
call print_refunds();
call auto_reject(283810751, '10/8/2022');
call print_refunds();