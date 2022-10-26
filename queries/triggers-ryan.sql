/* ----- TRIGGERS     ----- */

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


-- Trigger 6: Enforce the constraint that refund can only be made for successful projects.

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


-- Trigger 4 Test


-- Trigger 5 Test


-- Trigger 6 Test


