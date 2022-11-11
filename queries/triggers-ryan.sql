/* ----- TRIGGERS     ----- */

-- Trigger 4: Enforce the constraint that refund can only be approved for refunds requested within 90 days of deadline.
-- Trigger 4: Also enforce the constraint that refund not requested cannot be approved/rejected.

CREATE OR REPLACE FUNCTION reject_refunds_91_days_after_deadline ()
RETURNS TRIGGER AS $$ 

DECLARE  
    num_days_diff INT;

BEGIN

    SELECT Backs.request - Projects.deadline INTO num_days_diff
    FROM Backs, Rewards, Projects
    WHERE Backs.email = NEW.email AND Backs.id = NEW.pid AND Backs.name = Rewards.name AND Backs.id = Rewards.id AND Rewards.id = Projects.id;

    IF (num_days_diff > 90) THEN
        NEW.accepted:=false;
    END IF;
    RETURN NEW;

END;


$$ LANGUAGE plpgsql;

CREATE TRIGGER refund_request_auto_rejection
BEFORE INSERT ON Refunds
FOR EACH ROW EXECUTE FUNCTION reject_refunds_91_days_after_deadline();

CREATE OR REPLACE FUNCTION remove_status_on_refund_request()
RETURNS TRIGGER AS $$

DECLARE
    request DATE;

BEGIN

    SELECT Backs.request INTO request
    FROM Backs
    WHERE Backs.email = NEW.email AND Backs.id = NEW.pid;

    IF (request IS NULL) THEN
        RAISE EXCEPTION 'Refund not requested cannot be approved/rejected.';
        RETURN NULL;
    ELSE
        RETURN NEW;
    END IF;

END;

$$ LANGUAGE plpgsql;

CREATE TRIGGER no_status_on_refund_request
BEFORE INSERT ON Refunds
FOR EACH ROW EXECUTE FUNCTION remove_status_on_refund_request();


-- Trigger 5: Enforce the constraint that backers back before deadline.

CREATE OR REPLACE FUNCTION remove_back_after_deadline()
RETURNS TRIGGER AS $$ 

DECLARE  
	deadline DATE;

BEGIN

    SELECT Projects.deadline INTO deadline
    FROM Projects, Rewards
    WHERE Rewards.name = NEW.name AND Rewards.id = NEW.id AND Projects.id = Rewards.id;
    
    IF (NEW.backing > deadline) THEN
      RETURN NULL;
    ELSE
      RETURN NEW;
    END IF;

END;


$$ LANGUAGE plpgsql;

CREATE TRIGGER back_before_deadline
BEFORE INSERT ON Backs
FOR EACH ROW EXECUTE FUNCTION remove_back_after_deadline();


-- Trigger 6: Enforce the constraint that refund can only be requested for successful projects.

CREATE OR REPLACE FUNCTION check_refund_validity()
RETURNS TRIGGER AS $$ 

DECLARE  
	deadline DATE;
	pledged_amt INT;
	funding_goal INT;
BEGIN

    SELECT Projects.deadline INTO deadline
    FROM Projects, Rewards
    WHERE Rewards.name = NEW.name AND Rewards.id = NEW.id AND Projects.id = Rewards.id;

    SELECT Projects.goal INTO funding_goal
    FROM Projects, Rewards
    WHERE Rewards.name = NEW.name AND Rewards.id = NEW.id AND Projects.id = Rewards.id;

    SELECT SUM(amount) INTO pledged_amt
    FROM Backs
    WHERE id = NEW.id;

    
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


-- Trigger 4 Test
-- refund request status auto set to false
INSERT INTO Projects VALUES (1000,'cjanecek1v@chron.com', 'Food', '12/06/2022', 'Hamburger' ,'13/06/2022', 5000);
INSERT INTO Rewards VALUES ('FoodKing', 1000, 1000);
INSERT INTO Backs VALUES ('mbaldoni6@oracle.com', 'FoodKing', 1000, '12/06/2022', '13/06/2023', 2000);
INSERT INTO Refunds VALUES ('mbaldoni6@oracle.com', 1000, 652147422, '16/06/2023', true);

-- fails because refund has not been requested
INSERT INTO Backs VALUES ('odrohunv@ebay.com', 'FoodKing', 1000, '12/06/2022', null, 2000);
INSERT INTO Refunds VALUES ('odrohunv@ebay.com', 1000, 652147422, '16/06/2023', true);

-- Trigger 5 Test
-- not inserted because backing is after project deadline
INSERT INTO Backs VALUES ('cjanecek1v@chron.com', 'FoodKing', 1000, '14/06/2022', '13/06/2023', 2000);

-- Trigger 6 Test
-- request allowed because request is after deadline and pledged_amt = 6000 > goal = 5000
INSERT INTO Backs VALUES ('cjanecek1v@chron.com', 'FoodKing', 1000, '12/06/2022', null, 2000);
UPDATE Backs SET request = '14/06/2022' WHERE (email = 'odrohunv@ebay.com' AND id = 1000);

