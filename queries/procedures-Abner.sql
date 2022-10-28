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
) AS $$ -- add declaration here
BEGIN -- your code here -- Begin Transaction, auto rolls back if exception thrown
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
END; -- Commits transaction only if everythign above causes no errors

$$ LANGUAGE plpgsql;


/* TEST REMOVE IN FINAL*/
/* TEST PROCEDURES*/
CREATE OR REPLACE PROCEDURE print_user_count() AS $$ 
DECLARE 
-- user_count INT := select COUNT(*) FROM Users;
BEGIN 
    RAISE NOTICE  'User count: %', COUNT(*) cnt FROM Users;
    RAISE NOTICE  'Backer count: %', COUNT(*) cnt FROM Backers;
    RAISE NOTICE  'Creator count: %', COUNT(*) cnt FROM Creators;
END; 
$$ LANGUAGE plpgsql;

/* HAPPY CASES */
\i import.sql;

call add_user ( 'abnermtj@live.com.sg', 'Tolentino Abner Jr Morales','123123123',NULL,'Pasir Ris','123123','512022','Singapore', 'BOTH');
call print_user_count();
call add_user ( 'Notabnermtj@live.com.sg', 'NOT Tolentino Abner Jr Morales','123123123',NULL,'Pasir Ris','123123','512022','Singapore', 'BACKER');
call print_user_count();
call add_user ( 'yuthuan@live.com.sg', 'YuXuan','123123123','2','Pasir Ris','123123','512022','Singapore', 'CREATOR');
call print_user_count();

/* Exepect OUT
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

/* FAIL CASES */
/* BAD INPUT */
call add_user ( 'poop@live.com.sg', 'poop',12,NULL,'Pasir Ris',123123,512022,'Singapore', 'BOTH')
call print_user_count();
call add_user ( 'theo@live.com.sg', 'Theo pinto','123123123','1232123','Pasir Ris','123123','512022','Singapore', 'BACKERS');
call print_user_count();
call add_user ( 'ryan@live.com.sg', 'Ryan',12,NULL,'Pasir Ris','123123','512022','Singapore', 'NOTVALIDKEYWORD')
call print_user_count();

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

    FOR i IN 1 .. array_upper(names, 1) -- Is this function call allowed?
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
BEGIN -- your code here
    FOR backing IN SELECT * FROM Backs
    LOOP
        IF backing.request IS NOT NULL AND NOT EXISTS (SELECT * FROM REFUNDS r WHERE r.email = backing.email AND r.pid = backing.id) THEN /* IS A REQUEST */
            INSERT INTO Refunds
            values(backing.email, backing.id, eid, today, FALSE);
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;


/* ------------------------ */
