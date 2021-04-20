IF EXISTS(SELECT 1 FROM master..sysdatabases WHERE name = 'rental_office') DROP DATABASE rental_office
GO
CREATE DATABASE rental_office;
GO

CREATE TABLE rental_office..people_renting_apartments (

people_renting_apartments_ID char(4) NOT NULL PRIMARY KEY, 
first_name varchar(20) NOT NULL,
last_name varchar(20) NOT NULL,
identity_card char(9) NOT NULL UNIQUE,
date_of_birth datetime NOT NULL,
phone_number varchar(20) NOT NULL UNIQUE,
sex char(1) NOT NULL,

CONSTRAINT check_people_renting_apartments_ID CHECK(
	(people_renting_apartments_ID LIKE '[A-Z][A-Z][0-9][0-9]')),
CONSTRAINT check_identity_card_people_renting_apartments CHECK(
	(identity_card LIKE '[A-Z][A-Z][A-Z][0-9][0-9][0-9][0-9][0-9][0-9]')),
CONSTRAINT check_sex_people_renting_apartments CHECK (sex IN('K','M'))

);
GO

CREATE TABLE rental_office..apartment_owners (

apartment_owners_ID char(4) NOT NULL PRIMARY KEY, 
first_name varchar(20) NOT NULL,
last_name varchar(20) NOT NULL,
identity_card char(9) NOT NULL UNIQUE,
date_of_birth datetime NOT NULL,
phone_number varchar(20) NOT NULL UNIQUE,
sex char(1) NOT NULL,

CONSTRAINT check_apartment_owners_ID CHECK(
	(apartment_owners_ID LIKE '[A-Z][A-Z][0-9][0-9]')),
CONSTRAINT check_identity_card_apartment_owners CHECK(
	(identity_card LIKE '[A-Z][A-Z][A-Z][0-9][0-9][0-9][0-9][0-9][0-9]')),
CONSTRAINT check_sex_apartment_owners CHECK (sex IN('K','M'))

);
GO

CREATE TABLE rental_office..provinces (

provinces_ID char(2) PRIMARY KEY,
name varchar(20)

);
GO



CREATE TABLE rental_office..locations(

location_ID int NOT NULL PRIMARY KEY,
street varchar(50),
city varchar(50),
postal_code varchar(6),
provinces_ID char(2),

CONSTRAINT check_postal_code CHECK(
	(postal_code LIKE '[0-9][0-9][-][0-9][0-9][0-9]'))

);
GO

ALTER TABLE rental_office..locations ADD CONSTRAINT for_key_ID_provinces FOREIGN KEY (provinces_ID) REFERENCES provinces(provinces_ID);
GO


CREATE TABLE rental_office..departments (

department_ID int NOT NULL PRIMARY KEY,
manager_ID int,
location_ID int

);
GO

ALTER TABLE rental_office..departments ADD CONSTRAINT FK_location_ID FOREIGN KEY (location_ID) REFERENCES locations(location_ID);
GO

CREATE TABLE rental_office..jobs (

job_ID char(3) PRIMARY KEY,
name varchar(40),
min_salary money,
CONSTRAINT check_min_salary CHECK(min_salary > 0)

);
GO

CREATE TABLE rental_office..employees (

employee_ID int NOT NULL PRIMARY KEY,
first_name varchar(20) NOT NULL,
last_name varchar(20) NOT NULL,
phone_number varchar(20) NOT NULL UNIQUE,
date_of_birth datetime NOT NULL,
hire_date datetime NOT NULL,
salary money,
department_ID int,
job_ID char(3),

CONSTRAINT check_dates CHECK(date_of_birth < hire_date),
CONSTRAINT check_salary CHECK(salary > 0)

);
GO

ALTER TABLE rental_office..employees ADD CONSTRAINT FK_empl_department_ID FOREIGN KEY (department_ID) REFERENCES departments(department_ID);
ALTER TABLE rental_office..employees ADD CONSTRAINT FK_empl_job_ID FOREIGN KEY (job_ID) REFERENCES jobs(job_ID);
GO


CREATE TABLE rental_office..employee_archive (

employee_ID int NOT NULL,
start_date datetime NOT NULL,
end_date datetime NOT NULL,
department_ID int NOT NULL,
job_ID char(3),

CONSTRAINT check_start_end_dates CHECK(start_date < end_date)

);
GO

ALTER TABLE rental_office..employee_archive ADD CONSTRAINT FK_archive_department_ID FOREIGN KEY (department_ID) REFERENCES departments(department_ID);
ALTER TABLE rental_office..employee_archive ADD CONSTRAINT FK_archive_job_ID FOREIGN KEY (job_ID) REFERENCES jobs(job_ID);
GO


CREATE TABLE rental_office..apartments (

apartment_ID int NOT NULL PRIMARY KEY,
apartment_number int,
number_of_rooms int NOT NULL,
apartment_size int NOT NULL,
type_of_building varchar(20),
apartment_owners_ID char(4) NOT NULL,
department_ID int NOT NULL,
location_ID int,

CONSTRAINT check_apartment_number CHECK(apartment_number > 0),
CONSTRAINT check_apartment_size CHECK(apartment_size > 0),
CONSTRAINT check_number_of_rooms CHECK(number_of_rooms > 0)

);
GO

ALTER TABLE rental_office..apartments ADD CONSTRAINT FK_location_apartment_owners_ID FOREIGN KEY (apartment_owners_ID) REFERENCES apartment_owners(apartment_owners_ID);
ALTER TABLE rental_office..apartments ADD CONSTRAINT FK_location_department_ID FOREIGN KEY (department_ID) REFERENCES departments(department_ID);
GO
ALTER TABLE rental_office..apartments ADD CONSTRAINT FK_location_location_ID FOREIGN KEY (location_ID) REFERENCES locations(location_ID);


CREATE TABLE rental_office..rental_agreement (

rental_agreement_ID int IDENTITY(1,1) PRIMARY KEY, 
agreement_start_date datetime,
agreement_end_date datetime NOT NULL,
rental_price money NOT NULL,
number_of_people int NOT NULL,
people_renting_apartments_ID char(4) NOT NULL,
apartment_ID int NOT NULL,

CONSTRAINT check_number_of_people CHECK(number_of_people > 0),
CONSTRAINT check_rental_price CHECK(rental_price > 0),
CONSTRAINT check_agreement_dates CHECK(agreement_start_date < agreement_end_date)

);
GO


ALTER TABLE rental_office..rental_agreement ADD CONSTRAINT FK_rental_agreement_people_renting_apartments FOREIGN KEY (people_renting_apartments_ID) REFERENCES people_renting_apartments(people_renting_apartments_ID);
ALTER TABLE rental_office..rental_agreement ADD CONSTRAINT FK_rental_agreement_apartment_ID FOREIGN KEY (apartment_ID) REFERENCES apartments(apartment_ID);
GO




