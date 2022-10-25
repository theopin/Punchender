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
	reward_min_amt INT;

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

/* ------------------------ */


-- Trigger 1 Test

BEGIN;
SET CONSTRAINTS backers_creators_existence DEFERRED;
INSERT INTO Users VALUES ('def1@chron.com', 'Test1', '123','456');
INSERT INTO Creators VALUES ('def1@chron.com', 'India');


INSERT INTO Users VALUES ('def2@chron.com', 'Test2', '123','456');
INSERT INTO Backers VALUES ('def2@chron.com', 'abc', 'def', 'ghi', 'jkl');

INSERT INTO Users VALUES ('def3@chron.com', 'Test3', '123','456');
INSERT INTO Creators VALUES ('def3@chron.com', 'India');
INSERT INTO Backers VALUES ('def3@chron.com', 'abcd', 'defg', 'ghij', 'jklp');
INSERT INTO Users VALUES ('def4@chron.com', 'Test4', '123','456');
COMMIT;

SELECT * FROM Users WHERE email LIKE 'def%';
SELECT * FROM Backers WHERE email LIKE 'def%';
SELECT * FROM Creators WHERE email LIKE 'def%';

BEGIN;
SET CONSTRAINTS backers_creators_existence DEFERRED;
INSERT INTO Users VALUES ('def1@chron.com', 'Test1', '123','456');
INSERT INTO Creators VALUES ('def1@chron.com', 'India');


INSERT INTO Users VALUES ('def2@chron.com', 'Test2', '123','456');
INSERT INTO Backers VALUES ('def2@chron.com', 'abc', 'def', 'ghi', 'jkl');

INSERT INTO Users VALUES ('def3@chron.com', 'Test3', '123','456');
INSERT INTO Creators VALUES ('def3@chron.com', 'India');
INSERT INTO Backers VALUES ('def3@chron.com', 'abcd', 'defg', 'ghij', 'jklp');
COMMIT;

SELECT * FROM Users WHERE email LIKE 'def%';
SELECT * FROM Backers WHERE email LIKE 'def%';
SELECT * FROM Creators WHERE email LIKE 'def%';

DELETE FROM Backers WHERE email LIKE 'def%';
DELETE FROM Creators WHERE email LIKE 'def%';
DELETE FROM Users WHERE email LIKE 'def%';

-- Trigger 2 Test

INSERT INTO Backs VALUES ('mbaldoni6@oracle.com', 'Bentley', 7, '12/06/2022', '13/06/2022', 2000);
INSERT INTO Backs VALUES ('lsauvend@ox.ac.uk', 'Dodge', 69, '12/06/2022', '13/06/2022', 2000);

SELECT * FROM Backs WHERE email = 'mbaldoni6@oracle.com' OR email = 'lsauvend@ox.ac.uk';

DELETE FROM Backs WHERE email = 'mbaldoni6@oracle.com' or email = 'lsauvend@ox.ac.uk';

-- Trigger 3 Test

BEGIN;
INSERT INTO Projects VALUES (1000,'cjanecek1v@chron.com', 'Food', '12/06/2022', 'Hamburger' ,'13/06/2022', 5000);
INSERT INTO Rewards VALUES ('FoodKing', 1000, 1000);

INSERT INTO Projects VALUES (1001,'ekochs1l@nih.gov', 'Food', '12/06/2022', 'Chicken','13/06/2022', 5000);
COMMIT;

SELECT * FROM Projects WHERE id > 999;
SELECT * FROM Rewards WHERE id > 999;

BEGIN;
INSERT INTO Projects VALUES (1000,'cjanecek1v@chron.com', 'Food', '12/06/2022', 'Hamburger' ,'13/06/2022', 5000);
INSERT INTO Rewards VALUES ('FoodKing', 1000, 1000);
COMMIT;

SELECT * FROM Projects WHERE id > 999;
SELECT * FROM Rewards WHERE id > 999;

DELETE FROM Rewards WHERE id > 999;
DELETE FROM Projects WHERE id > 999;
