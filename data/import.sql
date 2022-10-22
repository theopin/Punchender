DROP TABLE IF EXISTS Employees, Users, Verifies, Backers, Creators, ProjectTypes, Projects, Updates, Rewards, Backs, Refunds CASCADE;

CREATE TABLE Employees (
  id     INT PRIMARY KEY,
  name   TEXT NOT NULL,
  salary NUMERIC NOT NULL CHECK (salary > 0)
);

CREATE TABLE Users (
  email  TEXT PRIMARY KEY,
  name   TEXT NOT NULL,
  cc1    TEXT NOT NULL,
  cc2    TEXT CHECK (cc1 <> cc2)
);

CREATE TABLE Creators (
  email   TEXT PRIMARY KEY
    REFERENCES Users(email) ON UPDATE CASCADE,
  country TEXT NOT NULL
);


CREATE TABLE ProjectTypes (
  name  TEXT PRIMARY KEY,
  id    INT NOT NULL REFERENCES Employees(id)
);

CREATE TABLE Backers (
  email   TEXT PRIMARY KEY
    REFERENCES Users(email) ON UPDATE CASCADE,
  street  TEXT NOT NULL,
  num     TEXT NOT NULL,
  zip     TEXT NOT NULL,
  country TEXT NOT NULL
);

CREATE TABLE Projects (
  id       INT PRIMARY KEY,
  email    TEXT NOT NULL
    REFERENCES Creators(email) ON UPDATE CASCADE,
  ptype    TEXT NOT NULL
    REFERENCES ProjectTypes(name) ON UPDATE CASCADE,
  created  DATE NOT NULL, -- alt: TIMESTAMP
  name     TEXT NOT NULL,
  deadline DATE NOT NULL CHECK (deadline >= created),
  goal     NUMERIC NOT NULL CHECK (goal > 0)
);

CREATE TABLE Updates (
  time    TIMESTAMP,
  id      INT REFERENCES Projects(id)
    ON UPDATE CASCADE, -- ON DELETE CASCADE (optional)
  message TEXT NOT NULL,
  PRIMARY KEY (time, id)
);

CREATE TABLE Rewards (
  name    TEXT,
  id      INT REFERENCES Projects(id)
    ON UPDATE CASCADE, -- ON DELETE CASCADE (optional)
  min_amt NUMERIC NOT NULL CHECK (min_amt > 0),
  PRIMARY KEY (name, id)
);

CREATE TABLE Verifies (
  email    TEXT PRIMARY KEY
    REFERENCES Users(email),
  id       INT NOT NULL REFERENCES Employees(id),
  verified DATE NOT NULL
);

CREATE TABLE Backs (
  email    TEXT REFERENCES Backers(email),
  name     TEXT NOT NULL,
  id       INT,
  backing  DATE NOT NULL, -- backing date
  request  DATE, -- refund request
  amount   NUMERIC NOT NULL CHECK (amount > 0),
  -- status will be derived via queries instead
  PRIMARY KEY (email, id),
  FOREIGN KEY (name, id) REFERENCES Rewards(name, id)
);

CREATE TABLE Refunds (
  email    TEXT,
  pid      INT,
  eid      INT NOT NULL REFERENCES Employees(id),
  date     DATE NOT NULL,
  accepted BOOLEAN NOT NULL,
  PRIMARY KEY (email, pid),
  FOREIGN KEY (email, pid) REFERENCES Backs(email, id)
);


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
