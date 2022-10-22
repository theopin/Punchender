\set localpath `pwd`'/employees.csv'

COPY employees(id, name, salary)
FROM :'localpath'
DELIMITER ','
CSV HEADER;

\set localpath `pwd`'/users.csv'

COPY users(email,name,cc1,cc2)
FROM :'localpath'
DELIMITER ','
CSV HEADER;


\set localpath `pwd`'/creators.csv'

COPY Creators (email, country)
FROM :'localpath'
DELIMITER ','
CSV HEADER;


\set localpath `pwd`'/backers.csv'

COPY Backers(email,street,num,zip,country)
FROM :'localpath'
DELIMITER ','
CSV HEADER;

\set localpath `pwd`'/project_types.csv'

COPY ProjectTypes (name, id)
FROM :'localpath'
DELIMITER ','
CSV HEADER;

\set localpath `pwd`'/projects.csv'

COPY Projects (id,email,ptype,created,name,deadline,goal)
FROM :'localpath'
DELIMITER ','
CSV HEADER;

\set localpath `pwd`'/updates.csv'

COPY Updates (time,id,message)
FROM :'localpath'
DELIMITER ','
CSV HEADER;

\set localpath `pwd`'/rewards.csv'

COPY Rewards (name, id, min_amt)
FROM :'localpath'
DELIMITER ','
CSV HEADER;

\set localpath `pwd`'/verifies.csv'

COPY Verifies (email,id,verified)
FROM :'localpath'
DELIMITER ','
CSV HEADER;


\set localpath `pwd`'/backs.csv'

COPY Backs (email, name, id, backing, request, amount)
FROM :'localpath'
DELIMITER ','
CSV HEADER;

\set localpath `pwd`'/refunds.csv'

COPY Refunds (email, pid, eid, date, accepted)
FROM :'localpath'
DELIMITER ','
CSV HEADER;
