-- Autorzy: 	Magdalena Wojciak, 224461
--		Kamil Bloch


USE rental_office

------------------------------------------------------------ZAPYTANIA------------------------------------------------------------


-- 1. Wyswietlenie tych wlascicieli lokali, u ktorych laczny miesięczny czynsz za obecnie wynajete lokale jest powyzej sredniej

BEGIN

	WITH currently_rented_apartments AS (
		SELECT DISTINCT a.apartment_ID, ra.rental_price
		FROM apartments a
		JOIN rental_agreement ra ON a.apartment_ID = ra.apartment_ID
		WHERE ra.agreement_end_date > GETDATE()
		)

	SELECT  ao.apartment_owners_ID,
			ao.last_name,
			SUM(cr.rental_price) AS [rental income]
	FROM	apartment_owners ao, apartments ap, currently_rented_apartments cr
	WHERE	ao.apartment_owners_ID = ap.apartment_owners_ID
	AND		cr.apartment_ID = ap.apartment_ID
	AND		cr.rental_price > (SELECT AVG(rental_price) FROM currently_rented_apartments)
	GROUP BY ao.apartment_owners_ID, ao.last_name

END


-- 2. Wyswietlenie sredniej ceny wynajmu za jeden metr kwadratowy lokalu (z zaaokragleniem do dwoch miejsc po przecinku), 
--    sredniego metrazu lokalu (przyjmujemy zaokraglenie w dol) w zaleznosci od wojewodztwa.
--    Posegregowanie wynikow malejaco wzgledem sredniej ceny wynajmu za 1 metr kwadratowy 

SELECT  p.name,
		ROUND(AVG(ra.rental_price/ap.apartment_size), 2) AS [avg rental price for square meter],
		FLOOR(AVG(ap.apartment_size)) AS [avg apartment size]
FROM apartments ap, rental_agreement ra, locations l, provinces p
WHERE ap.apartment_ID = ra.apartment_ID
AND l.location_ID = ap.location_ID
AND l.provinces_ID = p.provinces_ID
GROUP BY (p.name)
ORDER BY [avg rental price for square meter] DESC


-- 3. Wyswietlenie identyfikatorow wlascicieli mieszkan oraz liczby lokali przez nich posiadanych, ktorzy posiadaja wiecej niz 2 lokale.

SELECT  apartment_owners.apartment_owners_ID,
	COUNT(apartments.apartment_ID) AS [number of apartments]
FROM (apartments
INNER JOIN apartment_owners ON apartment_owners.apartment_owners_ID = apartments.apartment_owners_ID)
GROUP BY apartment_owners.apartment_owners_ID
HAVING COUNT(apartments.apartment_ID) > 2;


-- 4. Wyświetlenie malejąco częstotliwości podpisywania umów w zależności od miesiąca w procentach.

BEGIN

	DECLARE @number_of_rental_agreement int
	SET @number_of_rental_agreement = (SELECT COUNT(rental_agreement_ID) FROM rental_agreement)

	SELECT  DATENAME(month, ra.agreement_start_date) AS [month name],
			COUNT(ra.agreement_start_date) AS [number of rental agreements],
			ROUND((CAST(COUNT(ra.agreement_start_date) AS float)/@number_of_rental_agreement) * 100, 2) AS [frequency(%)]
	FROM rental_agreement ra
	GROUP BY MONTH(ra.agreement_start_date), DATENAME(month,ra.agreement_start_date)
	ORDER BY [frequency(%)] DESC

END

--    5. Wyswietelnie kwoty dodatku stazowego, ktory przysluguje pracownikowi w zaleznosci od liczby przeprawcowanych lat.
--    Jesli pracownik pracuje mniej niż 10 lat nie przysluje mu dodatek stazozwy
--    Jesli pracownik pracuje 10 lat lub wiecej jego dodatek stazowy jest wyliczany na podstawie przepracowanych lat, 
--    np 10 lat = 10% * wynagrodzenie pracownika, 11 lat = 11% * wynagrodzenie pracownika, itd
--    Jesli pracownik przepracuje wiecej niz 30 lat, jego dodatego stazowy utrzymuje sie na poziomie 30%
	
SELECT employee_ID, DATEDIFF(yyyy, hire_date, GETDATE()) as [number of years worked],
CASE
	WHEN DATEDIFF(yyyy, hire_date, GETDATE()) < 10 THEN 0
	WHEN DATEDIFF(yyyy, hire_date, GETDATE()) > 30 THEN 0.3 * salary
	ELSE DATEDIFF(yyyy, hire_date, GETDATE()) * salary /100
END AS Dodatek_stazowy
FROM employees


-- 6. Wyswietelnie identyfikatorow osob wynajmujacych oraz zajmowanych przez nich obecnie lokali wraz z data konca podpisanej umowy oraz informacji
--    ile czasu (wiecej niz pol roku, pol roku, mniej niz pol roku) pozostalo do konca umowy

SELECT	p.people_renting_apartments_ID,
	a.apartment_ID, 
	ra.agreement_end_date,
	CASE
		WHEN DATEDIFF(MONTH, GETDATE() ,ra.agreement_end_date) > 6 THEN 'More than six months remain to the end of the rental agreement'
		WHEN DATEDIFF(MONTH, GETDATE() ,ra.agreement_end_date) = 6 THEN 'Six months remain to the end of the rental agreement'
		ELSE 'Less than six months remain to the end of the rental agreement'
	END AS Information
FROM rental_agreement ra, people_renting_apartments p, apartments a
WHERE ra.apartment_ID = a.apartment_ID
AND ra.people_renting_apartments_ID = p.people_renting_apartments_ID
AND ra.agreement_end_date > GETDATE()


-- 7. Wyswietlenie listy lokali w danym miescie oraz informacji, ktory oddzial biura zajmuje sie danym lokalem

SELECT	l.city,
	a.apartment_ID, 
	a.department_ID
FROM apartments a, locations l
WHERE a.location_ID=l.location_ID 
AND a.apartment_ID NOT IN (	SELECT ra.apartment_ID 
				FROM rental_agreement ra
				WHERE ra.agreement_end_date > GETDATE())
						

-- 8. Porownanie liczby wynajetych lokali w 2019 roku i w dobie covidowej - rok 2020

SELECT y19.*, y20.year_2020 
FROM
	(SELECT MONTH(agreement_start_date) AS [month_number], 
		DATENAME(month, agreement_start_date) AS [month_name],
		COUNT(rental_agreement_ID) AS [year 2019] 
		FROM rental_agreement 
		WHERE YEAR(agreement_start_date) = 2019 
		GROUP BY MONTH(agreement_start_date), DATENAME(month, agreement_start_date)) AS y19,

	(SELECT month(agreement_start_date) AS [month_number], 
		DATENAME(month, agreement_start_date) AS [name_miesiaca],
		COUNT(rental_agreement_ID) AS [year_2020] 
		FROM rental_agreement 
		WHERE YEAR(agreement_start_date) = 2020 
		GROUP BY MONTH(agreement_start_date), DATENAME(month, agreement_start_date)) AS y20
WHERE y19.[month_number]=y20.[month_number]


-- 9. Wyswietlenie tych lokali (ID) wraz z adresem oraz numerem oddzialu, ktore dla zadeklarowanego wojewodztwa, nigdy nie byly wynajete

DECLARE @name_of_the_provinces varchar(20)
SET @name_of_the_provinces = 'PODLASKIE'

BEGIN
	
	WITH apartments_in_the_provinces AS (
	SELECT DISTINCT a.apartment_ID
	FROM apartments a
	JOIN rental_agreement u ON a.apartment_ID = u.apartment_ID
	)

	SELECT	a.apartment_ID, 
		CONCAT(l1.street, a.apartment_number, ', ', l1.postal_code, ' ', l1.city) AS [address],
		d.department_ID
	FROM apartments a, locations l1, provinces p, departments d, locations l2
	WHERE a.location_ID = l1.location_ID
	AND a.department_ID = d.department_ID
	AND d.location_ID = l2.location_ID
	AND l2.provinces_ID = p.provinces_ID
	AND p.name = @name_of_the_provinces
	AND a.apartment_ID NOT IN (SELECT * FROM apartments_in_the_provinces)

END

-- 10. Wyswietlenie poprzez kursor pracownikow (ich nazwisk i identyfikatorow) pracujacych w podanym wojewodztwie.
--     Wyswietlenie komunikatu odnosnie sumy pracownikow w podanym wojewodztwie.

BEGIN	
	DECLARE @employee_last_name varchar(20),
		@empl_id int,
		@number int,
		@prov_id char(2),
		@prov_name varchar(20)

	SET @number = 0		
	SET @prov_id = 'EL'

	SET @prov_name = (SELECT p.name FROM provinces p WHERE p.provinces_ID = @prov_id)

	DECLARE c CURSOR FOR (	SELECT e.last_name, e.employee_ID
				FROM employees e, departments d, locations l
				WHERE d.department_ID = e.department_ID
				AND d.location_ID = l.location_ID
				AND l.provinces_ID = @prov_id)
	OPEN c
	FETCH NEXT FROM c INTO @employee_last_name, @empl_id
	WHILE @@FETCH_STATUS = 0 
		BEGIN 

			SET @number = @number + 1
			PRINT 'Employee: ' + @employee_last_name + ', id = ' + CONVERT(varchar(20), @empl_id)
			FETCH NEXT FROM c INTO @employee_last_name, @empl_id

		END
	
		IF (@number >= 1)
			PRINT 'Province: ' + @prov_name + ' employs: ' + CONVERT(varchar(20), @number) + ' workers.'
		ELSE
			PRINT 'Province: ' + @prov_name + ' does not employ any workers. '

	CLOSE c
	DEALLOCATE c
END


-- 11. Wyswietlenie rankingu lokali w poszczegolnych miastach biorac pod uwage ich metraz.

SELECT	a.apartment_ID,
	a.apartment_size,
	l.city,
	DENSE_RANK() OVER (PARTITION BY l.city ORDER BY a.apartment_size DESC) AS Ranking
FROM apartments a 
JOIN locations l ON a.location_ID = l.location_ID


-- 12. Wyswietlenie na jakie rodzaje lokali (type_of_building) naczesciej decyduja sie osoby wynajmujace w danym wojewodztwie
--     Posegregowane od najwiekszej do najmniejszej ilosci w danym wojewodztwie

SELECT	l.provinces_ID,
	a.type_of_building,
	COUNT(a.type_of_building) AS [How many]
FROM rental_agreement u
JOIN apartments a ON u.apartment_ID = a.apartment_ID
JOIN locations l ON l.location_ID = a.apartment_ID
GROUP BY a.type_of_building, l.provinces_ID
ORDER BY l.provinces_ID, [How many] DESC


-- 13. Wyswietlenie pracownikow obchodzacych urodziny, badz rocznice zatrudnienia w biezacym miesiacu w poszczegolnych miastach.

SELECT 	l.city,
	CONCAT(e.first_name, ' ', e.last_name) as Employee,
	CASE
		WHEN MONTH(GETDATE()) = MONTH(e.date_of_birth) THEN 'Birthday'
		WHEN MONTH(GETDATE()) = MONTH(e.hire_date) THEN 'Anniversary of employment'
	END AS Occasion
FROM locations l, departments d, employees e
WHERE l.location_ID = d.location_ID
AND d.department_ID = e.department_ID
AND (MONTH(GETDATE()) = MONTH(e.date_of_birth)
OR MONTH(GETDATE()) = MONTH(e.hire_date))


-- 14. Wyswietlenie identyfikatorow pracownikow zwolnionych i zatrudnionych w tym samym miesiacu tego samego roku i miasta w którym mialo to miejsce.

SELECT DISTINCT l.city,
		e.employee_ID as [dismissed employees], 
		arch.employee_ID as [hired employees]
FROM employees e, employee_archive arch, departments d, locations l
WHERE e.department_ID = arch.department_ID
AND e.department_ID = d.department_ID
AND d.location_ID = l.location_ID
AND MONTH(arch.end_date) = MONTH(e.hire_date)
AND YEAR(arch.end_date) = YEAR(e.hire_date)


-- 15. Wyswietlenie poprzez kursor aoi, ich numerów telefonów i pełnych addressów api w budynkach danego rodzaju w danym podztwie.

BEGIN	
	DECLARE @owners varchar(20),
		@phone_num varchar(14),
		@address varchar(50),
		@type varchar(20),
		@prov_id char(2)

	SET @type = 'kamienica'
	SET @prov_id = 'LL'

	DECLARE c CURSOR FOR (	SELECT DISTINCT CONCAT(ao.first_name, ' ', ao.last_name) as Owner, 
						ao.phone_number, 
						CONCAT(l.street, ' ', a.apartment_number, ', ', l.postal_code, ' ', l.city) as Address
				FROM apartment_owners ao, locations l, apartments a
				WHERE a.apartment_owners_ID = ao.apartment_owners_ID
				AND a.location_ID = l.location_ID
				AND l.provinces_ID = @prov_id
				AND a.type_of_building = @type)
	OPEN c
	FETCH NEXT FROM c INTO @owners, @phone_num, @address
	WHILE @@FETCH_STATUS = 0 
		BEGIN 

			PRINT 'Owner: ' + @owners + ', his phone muber: ' + @phone_num + '. Apartment address: ' + @address
			FETCH NEXT FROM c INTO @owners, @phone_num, @address

		END
	CLOSE c
	DEALLOCATE c
END

-------------------------------------------------- FUNKCJE --------------------------------------------------

-- 1. Funkcja, ktora na podstawie apartment_ID sprawdza czy dany lokal jest dostepny do wynajecia.  
--    Jesli lokal jest dostepny zwraca 1, jesli nie zwraca 0


IF EXISTS (	SELECT * FROM sys.objects 
		WHERE object_id = OBJECT_ID(N'dbo.check_availability') 
		AND type IN ( N'FN', N'IF', N'TF', N'FS', N'FT' ))
DROP FUNCTION dbo.check_availability
GO 


CREATE FUNCTION check_availability (@apart_id int) RETURNS int
BEGIN
	DECLARE @is_available int

	IF (@apart_id NOT IN (	SELECT ra.apartment_ID 
				FROM rental_agreement ra
				WHERE ra.agreement_end_date > GETDATE()))
		BEGIN
			SET @is_available = 1
		END
		
	ELSE
		BEGIN
			SET @is_available = 0
		END
	
	RETURN @is_available

END
GO

--Sprawdzenie dostepnosci wszystkich mieszkan
SELECT DISTINCT apartment_ID,
		dbo.check_availability(apartment_ID) AS [Availability]
FROM apartments


-- 2. Funkcja, ktora na podstawie numeru dowodu sprawdza, czy dokument jest prawdziwy (czy sumy kontrolne się zgadzają)


IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.check_correctness_of_identity_card') 
					AND type IN ( N'FN', N'IF', N'TF', N'FS', N'FT' ))

DROP FUNCTION dbo.check_correctness_of_identity_card
GO 


CREATE FUNCTION check_correctness_of_identity_card (@iden_card varchar(9)) RETURNS varchar(12)
BEGIN
	DECLARE @is_correct varchar(12)

		BEGIN
			DECLARE @first int, @second int, @third int, @result int

			SET @first = ASCII(SUBSTRING(@iden_card, 1, 1)) - 55
			SET @second = ASCII(SUBSTRING(@iden_card, 2, 1)) - 55
			SET @third = ASCII(SUBSTRING(@iden_card, 3, 1)) - 55

			SET @result = 7 * @first + 3 * @second + 1 * @third
			+ 9 * SUBSTRING(@iden_card, 4, 1) + 7 * SUBSTRING(@iden_card, 5, 1)
			+ 3 * SUBSTRING(@iden_card, 6, 1) + 1 * SUBSTRING(@iden_card, 7, 1)
			+ 7 * SUBSTRING(@iden_card, 8, 1) + 3 * SUBSTRING(@iden_card, 9, 1)
			IF (@result % 10 = 0)
				SET @is_correct = 'CORRECT'
			ELSE
				SET @is_correct = 'INCORRECT'
		END

	RETURN @is_correct
END
GO

-- Sprawdzenie poprawnosci dowodow w bazie. Na potrzeby zadania wprowadzone dane ze sfalszowanym dowodem
SELECT people_renting_apartments_ID, identity_card, dbo.check_correctness_of_identity_card(identity_card) FROM people_renting_apartments



-------------------------------------------------- PROCEDURY --------------------------------------------------

-- 1. Procedura, ktora podniesie czynsz lokalu o podany procent. Jesli lokal posiada powierzchnie mniejsza niz 45 m nie pozwol na podwyzke
--    Dzialanie tylko dla lokali ktore sa obecnie wynajete. WYKORZYSTANIE STWORZONEJ FUNKCJI check_availability - jesli mieszkanie 
--    jest niedostepne (0) tzn ze jest wynajete. Na koniec wyswietlenie stosownego komunikatu.
--    Przyjmujemy domyslne wartosci: procent podwyzki = 5%

IF EXISTS(SELECT 1 FROM sys.objects WHERE name = 'raise_the_rental_price')
DROP PROCEDURE raise_the_rental_price
GO

CREATE PROCEDURE raise_the_rental_price (@aprat_num int,
					 @percent int =  5)					 
AS
	BEGIN
		DECLARE @rise float,
			@apartment_area int,
			@previous_value money,
			@new_value money
		
		SET @rise = 0.01 * @percent

		SET @apartment_area = (	SELECT a.apartment_size
					FROM apartments a
					WHERE a.apartment_ID = @aprat_num)

			IF (dbo.check_availability(@aprat_num) = 0)
			BEGIN
				IF (@apartment_area >= 45)
					BEGIN

						SET @previous_value = (	SELECT ra.rental_price 
									FROM rental_agreement ra 
									WHERE ra.apartment_ID = @aprat_num 
									AND agreement_end_date > GETDATE())

						UPDATE rental_office.dbo.rental_agreement
						SET rental_price = rental_price + @rise * rental_price
						WHERE apartment_ID = @aprat_num
						AND agreement_end_date > GETDATE()

						SET @new_value = (	SELECT ra.rental_price 
									FROM rental_agreement ra 
									WHERE ra.apartment_ID = @aprat_num 
									AND agreement_end_date > GETDATE())

						PRINT 'In apartment number: ' + CONVERT(varchar(4), @aprat_num)  
						+ ' the new value of the rent is: ' + CONVERT(varchar, @new_value) 
						+ 'PLN, and the previous value was: ' + CONVERT(varchar, @previous_value) +'PLN.'

					END

				ELSE
					BEGIN

						PRINT 'In apartment number: ' + CONVERT(varchar(4), @aprat_num)  
						+ ' you cannot increase rental price because it has an area of: ' 
						+ CONVERT(varchar(4), @apartment_area) + ' square meters.'

					END
			END

		ELSE
			BEGIN

				PRINT 'In apartment number: ' + CONVERT(varchar(4), @aprat_num) 
				+ ' the rental price cannot be increased as it is not currently rented out'

			END

	END
GO

--Lokal, ktory spelnia wszystkie wymagania do podwyzki 
EXEC dbo.raise_the_rental_price 3
GO

--Lokal, ktory nie jest wynajety, wiec nie spelnia wymagan do podwyzki
EXEC dbo.raise_the_rental_price 23
GO

--Lokal, ktory jest wynajety, ale jego metraz jest mniejsza niz 45 m, wiec nie spelnia wymagan do podwyzki
EXEC dbo.raise_the_rental_price 1
GO


-- 2. Procedura, ktora wyswietla tych pracownikow oraz ich stanowisko w danym oddziale, ktorzy zarabiaja pensje 
--    rowna minimalnej (wartosc min_salary w tabeli jobs)

IF EXISTS(SELECT 1 FROM sys.objects WHERE name = 'show_employees')
DROP PROCEDURE show_employees
GO

CREATE PROCEDURE show_employees (@depart_id int = 30)					 
AS
	BEGIN
	
		SELECT	CONCAT(	LEFT(e.first_name, 1), '. ', e.last_name) AS [employee],
				j.name AS [job title]
		FROM employees e, departments d, jobs j
		WHERE e.department_ID = d.department_ID
		AND d.department_ID = @depart_id
		AND e.job_ID = j.job_ID
		AND e.salary = j.min_salary

	END
GO

EXEC dbo.show_employees
GO

-- 3. Procedura, ktora na podstawie stazu pracy wylicza ile dni urlopu przysluguje pracownikowi (jesli staz
--    jesli staz pracy jest mniejszy niz 10 lat - pracownikowi przysluguje 20 dni urlopu, jesli staz pracy jest
--    wiekszy lub rowny 10 lat - pracownikowi przysluguje 26 dni urlopu. Wyswietlenie stosownych informacji

IF EXISTS(SELECT 1 FROM sys.objects WHERE name = 'length_of_vacation')
DROP PROCEDURE length_of_vacation
GO

CREATE PROCEDURE length_of_vacation (@empl_id int = 1)					 
AS
	BEGIN
	
		SELECT	CASE
				WHEN DATEDIFF(YEAR, e.hire_date, GETDATE()) >= 10 THEN 'The employee is entitled to 26 days of vacation'
				WHEN DATEDIFF(YEAR, e.hire_date, GETDATE()) < 10 THEN 'The employee is entitled to 20 days of vacation'
			END AS Information
		FROM employees e
		WHERE e.employee_ID = @empl_id

	END
GO

-- Wywolanie z domyslnym parametrem
EXEC dbo.length_of_vacation
GO

-- Wywolanie z parametrem
EXEC dbo.length_of_vacation 6
GO


-- 4. Procedura, ktora wynajmuje lokal. Sprawdza czy osoba, ktora chce go wynajac nie sfalszowala dowodu (funkcja check_correctness_of_identity_card) 
--    oraz sprawdza czy mieszkanie jest obecnie wynajete (funkcja check_availability)

IF EXISTS(SELECT 1 FROM sys.objects WHERE name = 'rent_an_apartment')
DROP PROCEDURE rent_an_apartment
GO

CREATE PROCEDURE rent_an_apartment (	@aprat_num int,
					@people_renting_apart char(4),
					@end date,
					@rent_price money,
					@how_many_people int)					 
AS
	BEGIN
		
		DECLARE @iden_card char(9)

		IF(@aprat_num IN (SELECT apartment_ID FROM apartments))
		
			BEGIN
			
				IF(dbo.check_availability(@aprat_num) = 1)
				
					BEGIN
					
						IF(@people_renting_apart IN (SELECT people_renting_apartments_ID FROM people_renting_apartments))
						
							BEGIN
								SET @iden_card = (SELECT identity_card FROM people_renting_apartments WHERE people_renting_apartments_ID = @people_renting_apart) 
								
									IF(dbo.check_correctness_of_identity_card(@iden_card) = 'CORRECT')
										BEGIN
										
											IF(@end > DATEADD(month, 3, GETDATE()) AND @rent_price > 0 AND @how_many_people > 0)
												BEGIN
													INSERT INTO rental_office..rental_agreement VALUES (GETDATE(), @end, @rent_price, @how_many_people, @people_renting_apart, @aprat_num)
													PRINT 'Apartament number : ' + CONVERT(varchar, @aprat_num) + ' has been rented to client number: ' + CONVERT(varchar, @people_renting_apart)
												END
											
											ELSE
												PRINT 'Incorrect data! (agreement end date, rental price or number of people)'
										END

									ELSE
										PRINT 'The person has a falsified identity card!'
							END
						
						ELSE
							PRINT 'No client in database!'
					END
				
				ELSE
					PRINT 'The apartment is currently rented out!'
			END

		ELSE
			PRINT 'No apartment in database!'	

	END
GO

--Wynajety obecnie lokal
EXEC dbo.rent_an_apartment 1, 'KN01', '2022/12/12', 1200, 1
GO

--Niepoprawna data konca
EXEC dbo.rent_an_apartment 23, 'KN01', '2012/12/12', 1200, 1
GO

--Niepoprawny czynsz
EXEC dbo.rent_an_apartment 23, 'KN01', '2022/12/12', 0, 2
GO

--Niepoprawna number osob
EXEC dbo.rent_an_apartment 23, 'KN01', '2022/12/12', 1200, 0
GO

--Falszywy dowod
EXEC dbo.rent_an_apartment 23, 'GZ11', '2022/12/12', 1200, 2
GO

--Wszystko poprawne
EXEC dbo.rent_an_apartment 38, 'KN01', '2022/12/12', 1200, 2
GO

SELECT * FROM rental_agreement
ORDER BY rental_agreement_ID DESC



-------------------------------------------------- WYZWALACZE --------------------------------------------------

-- 1. Wyzwalacz, ktory po usunieciu pracownika z tabeli employees przeniesie go do tabeli employee_archive. 

IF EXISTS (SELECT * FROM sys.objects WHERE [name] = N'move_to_archive' AND [type] = 'TR')
DROP TRIGGER dbo.move_to_archive;
GO

CREATE TRIGGER move_to_archive
ON rental_office.dbo.employees
FOR DELETE 
AS
BEGIN

	DECLARE @emp_id int,
		@hire date,
		@depart_id int,
		@job_id char(3)

	SET @emp_id = (SELECT employee_ID FROM deleted)
	SET @hire = (SELECT hire_date FROM deleted)
	SET @depart_id = (SELECT department_ID FROM deleted)
	SET @job_id = (SELECT job_ID FROM deleted)

    	INSERT INTO rental_office..employee_archive VALUES (@emp_id, @hire, GETDATE(), @depart_id, @job_id)


END;
GO

-- Sprawdzenie poprawnosci dzialania wyzwalacza
-- Usuniecie pracownika o ID = 24
DELETE FROM employees
WHERE employee_ID = 24

-- Proba wyswietlenia, z tabeli employees, pracownika o ID = 24
SELECT * FROM employees
WHERE employee_ID = 24
GO

-- Wyswietlenie danych z tabeli employee_archive (posegregowanych od najnowszej daty zakonczenia pracy)
SELECT * FROM employee_archive
ORDER BY end_date DESC


	
-- 2. Wyzwalacz, ktory zezwala na aktualizacje daty zakończenia umowy, gdy zostało więcej niż 3 mies do konca umowy 
--    oraz gdy wybierzemy nową date końca na termin dalszy niż 3 mies od teraz

IF EXISTS (SELECT * FROM sys.objects WHERE [name] = N'finish_rental_agreement_earlier' AND [type] = 'TR')
DROP TRIGGER dbo.finish_rental_agreement_earlier;
GO

CREATE TRIGGER finish_rental_agreement_earlier
ON rental_office.dbo.rental_agreement
INSTEAD OF UPDATE 
AS
BEGIN
	DECLARE @current_date date,
		@new_date date

	SET @current_date = (	SELECT ra.agreement_end_date 
				FROM rental_agreement ra, inserted i
				WHERE ra.rental_agreement_ID = i.rental_agreement_ID)
	SET @new_date = (SELECT inserted.agreement_end_date FROM inserted)

	IF(DATEADD(month, 3, GETDATE()) > @current_date)
		BEGIN
			PRINT 'Less than 3 months remain until the end of the rental agreement,  it cannot be shortened.'
		END

	ELSE IF(DATEADD(month, 3, GETDATE()) > @new_date)
		BEGIN
			PRINT 'The rental agreement may be shortened to three months from today'
		END

	ELSE
		BEGIN
			UPDATE rental_agreement
			SET agreement_end_date = @new_date 
			WHERE rental_agreement_ID = (SELECT inserted.rental_agreement_ID FROM inserted)

			PRINT 'The rental agreement was successfully shortened from: ' + CONVERT(varchar(20), @current_date) + ' to: ' + CONVERT(varchar(20), @new_date)
		END
END;
GO


--Proba skrocenia umowy, ktora kończy sie za mniej niż 3 miesiace
UPDATE rental_agreement
SET agreement_end_date = '2021/04/22'
WHERE rental_agreement_ID = 153

-- Sprawdzenie czy data ulegla zmianie
SELECT rental_agreement_ID, agreement_end_date FROM rental_agreement where rental_agreement_ID = 153


--Proba skrocenia umowy do mniej niz 3 miesiecy od teraz
UPDATE rental_agreement
SET agreement_end_date = '2021/04/22'
WHERE rental_agreement_ID = 158

-- Sprawdzenie czy data ulegla zmianie
SELECT rental_agreement_ID, agreement_end_date FROM rental_agreement where rental_agreement_ID = 158


--Skrocenie umowy
UPDATE rental_agreement
SET agreement_end_date = '2021/08/22'
WHERE rental_agreement_ID = 175

-- Sprawdzenie czy data ulegla zmianie
SELECT rental_agreement_ID, agreement_end_date FROM rental_agreement where rental_agreement_ID = 175




-- 3. Wyzwalacz ktory po dodaniu pracownika sprawdza czy jego pensja nie jest zbyt niska, jesli tak zwieksza ja do minimum

IF EXISTS (SELECT * FROM sys.objects WHERE [name] = N'add_employee' AND [type] = 'TR')
DROP TRIGGER dbo.add_employee;
GO

CREATE TRIGGER add_employee
ON rental_office.dbo.employees
AFTER INSERT
AS
BEGIN
	DECLARE @min_salary int,
		@inserted_salary int

	SET @min_salary = (	SELECT j.min_salary 
				FROM jobs j, inserted i
				WHERE j.job_ID=i.job_ID)
	SET @inserted_salary = (SELECT salary FROM inserted)
	
	IF(@inserted_salary < @min_salary)
		BEGIN
			
			PRINT 'The introduced salary does not comply with the guidelines. The salary has been increased to the minimum requirements.'
			UPDATE employees
			SET salary = @min_salary
			WHERE employee_ID = (SELECT employee_ID FROM inserted)

		END
END;
GO

--Wprowadzenie pracownika ze zbyt niska salary
INSERT INTO rental_office..employees
VALUES (123, 'Jan', 'Janowski', '(+48)212312312', '1999-01-01', GETDATE(), 2000, 160, 'ANL')

--Sprawdzenie czy salary ulegla zmianie
SELECT * FROM employees WHERE employee_ID=123
