--      ====== EX6 ======

-- pentru o subscriptie afisati toate filmele ei
-- + toti actorii fiecarui film

-- varray
create or replace type actori as varray(20) of varchar2(50);

CREATE OR REPLACE PROCEDURE filme_din_subscriptie(v_nume_subscriptie SUBSCRIPTIE.TIP%TYPE)
AS
    -- tablou indexat care retine numele filmelor
    type filme is table of FILM.denumire%type index by pls_integer;
    v_filme filme;

    -- tablou imbricat care retine id-ul filmelor
    type filme_id is table of ACTOR.nume%type;
    v_filme_id filme_id;

    -- varray care contine numele actorilor
    v_actori actori;

    v_subscriptie_id SUBSCRIPTIE.subscriptie_id%type;

BEGIN
    -- obtine id-ul subscriptiei
    select unique SUBSCRIPTIE_ID
    into v_subscriptie_id
    from SUBSCRIPTIE
    where TIP = v_nume_subscriptie;

    -- obtin toate numele filmelor si id-urile lor in tabloul indexat v_filme/v_filme_id
    select DENUMIRE, FILM.FILM_ID
    bulk collect into v_filme, v_filme_id
    from FILM
    join SUBSCRIPTIE_FILM on FILM.FILM_ID = SUBSCRIPTIE_FILM.FILM_ID
    where SUBSCRIPTIE_FILM.SUBSCRIPTIE_ID = v_subscriptie_id;

    DBMS_OUTPUT.PUT_LINE('      Subscriptia ' || v_nume_subscriptie || ' contine:');

    for i in v_filme_id.first..v_filme_id.last loop
        DBMS_OUTPUT.PUT_LINE('  ' || v_filme(i) || ': ');

        -- pentru fiecare film selectam actorii care joaca in el
        select nume
        bulk collect into v_actori
        from ACTOR
        join ROL_JUCAT on ACTOR.ACTOR_ID = ROL_JUCAT.ACTOR_ID
        where ROL_JUCAT.FILM_ID = v_filme_id(i);

        for i in v_actori.first..v_actori.last loop
            DBMS_OUTPUT.PUT_LINE(v_actori(i));
            end loop;

        v_actori.DELETE;

        end loop;
END;
/

begin
    filme_din_subscriptie('basic');
end;
/

-- =================================================================

--      ====== EX7 ======
-- pentru fiecare Serial cu id-ul in (1,3,6) afisati numele tuturor
-- episoadelor care apartin
create or replace type serialId as varray(10) of number(6);

-- functie ajutatoare pentru a verifica daca un serial apartine unui varray de seriale
-- am facut asta ca primeam o eroare ciudata si asta mi s-a parut un workaound desutl de bun
create or replace function verifica_serial(v_serialId SERIAL.SERIAL_ID%TYPE, listaId serialId) RETURN NUMBER AS
    v_found number(1) := 0;
begin
    for i in 1..listaId.COUNT loop
        if v_serialId = listaId(i) then
            v_found := 1;
            return v_found;
        end if;
    end loop;

    return v_found;
end;
/

CREATE OR REPLACE PROCEDURE episoade_din_seriale(listaId serialId) AS
    v_id_ser SERIAL.serial_id%type;

    v_nume_ser SERIAL.denumire%type;
    v_nume_episod varchar2(50);
    v_areEpisod number(1) := 0;

    -- cursor clasic
    CURSOR seriale IS
        select SERIAL_ID, DENUMIRE
        from SERIAL
        WHERE verifica_serial(SERIAL_ID, listaId) = 1;

    -- cursor parametrizat dependent de cel anterior
    CURSOR episod(id number) IS
        select DENUMIRE
        from EPISOD
        where SERIAL_ID = id;

begin
    OPEN seriale;
    loop
        Fetch seriale into v_id_ser, v_nume_ser;
        exit when seriale%notfound;

        v_areEpisod := 0;

        DBMS_OUTPUT.PUT_LINE('Serialul: ' || v_nume_ser);

        -- deschidem noul cursor cu parametrul din cursorul anterior
        OPEN episod(v_id_ser);
        loop
            Fetch episod into v_nume_episod;
            exit when EPISOD%notfound;
            v_areEpisod := 1;
            DBMS_OUTPUT.PUT_LINE('  ' || v_nume_episod);
        end loop;

        close episod;

        if v_areEpisod = 0 then DBMS_OUTPUT.PUT_LINE('  Nu are episoade');
        end if;

    end loop;
    close seriale;
end;
/

declare
    v_lista_serialId serialId := serialId(1,3,6);
begin
    episoade_din_seriale(v_lista_serialId);
end;
/
-- =================================================================

--      ====== EX8 ======
-- pentru o subscriptie data sa se ia serialul cu durata cea mai mare si
-- sa se afiseze cati actori are
CREATE OR REPLACE FUNCTION durata_subscriptie(tip_subscriptie subscriptie.tip%type) return Number
AS
    type tipSubscriptie is table of SUBSCRIPTIE.TIP%type index by pls_integer;

    v_subscriptie_id SUBSCRIPTIE.subscriptie_id%type;
    v_tipuri_subscriptii tipSubscriptie;
    v_hasBeenFound boolean := false;
    v_maxSerialDuration number(4) := 0;
    v_idSerialMaxDuration SERIAL.SERIAL_ID%type;
    v_countActors number(3) := 0;
    v_foundActors boolean := false;

    -- cursor care ne ofera id-ul serialelor din subscriptia data ca parametru si duratat totala
    -- aflata adunand durata fiecarui episod din acel serial
    CURSOR durataEpisoade(id_subscriptie SUBSCRIPTIE.SUBSCRIPTIE_ID%type) IS
        with durataEpisod as (select S2.SERIAL_ID, S2.DENUMIRE nume, sum(DURATA) suma
                              from EPISOD
                                       join SERIAL S2 on S2.SERIAL_ID = EPISOD.SERIAL_ID
                              group by S2.SERIAL_ID, S2.DENUMIRE)
        select ss.SERIAL_ID, de.suma
        from SUBSCRIPTIE_SERIAL ss
                 join durataEpisod de on de.SERIAL_ID = ss.SERIAL_ID
        where ss.SUBSCRIPTIE_ID = v_subscriptie_id
        order by de.suma desc;

    -- cursor care ne da pentru fiecare serial cati actori are
    -- TODO: intrebare, era mai bine sa fac cu left/right join si sa verific daca count ul e 0
        -- sau e bine si asa?
    CURSOR actors IS
        select sa.SERIAL_ID id, count(*) nr
        from ACTOR a
                 Join SERIAL_ACTOR sa on a.ACTOR_ID = sa.ACTOR_ID
        group by sa.serial_id;

    type serial_info is table of durataEpisoade%rowtype index by pls_integer;
    v_infoSeriale serial_info;

    type actors_info is table of actors%rowtype index by pls_integer;
    v_infoActors actors_info;

    -- exceptii
    NAME_NOT_FOUND EXCEPTION;
    NO_ACTORS_FOUND EXCEPTION;
BEGIN
    -- selectarea tututor tipurilor si verificarea ca tipul dat ca parametru sa existe
    -- in aceasta lista
    select lower(tip)
    bulk collect into v_tipuri_subscriptii
    from SUBSCRIPTIE;

    for i in v_tipuri_subscriptii.first..v_tipuri_subscriptii.last loop
        if lower(tip_subscriptie) = v_tipuri_subscriptii(i) then
            v_hasBeenFound := true;
        end if;
    end loop;

    if v_hasBeenFound = false then
        RAISE NAME_NOT_FOUND;
    end if;
    -- ========================

    -- daca avem un tip corect ii aflam id-ul
    select SUBSCRIPTIE_ID
    into v_subscriptie_id
    from SUBSCRIPTIE
    where lower(TIP) = lower(tip_subscriptie);
    -- ===============

    -- colectam informatia pentru seriale, adica (id, durata totala)
    OPEN durataEpisoade(v_subscriptie_id);
    FETCH durataEpisoade bulk collect into v_infoSeriale;
    CLOSE durataEpisoade;

    -- parcurgem serialele si luam id-ul celui cu cea mai mare durata
    FOR i IN v_infoSeriale.FIRST..v_infoSeriale.LAST LOOP
        if v_maxSerialDuration < v_infoSeriale(i).suma then
            v_maxSerialDuration := v_infoSeriale(i).suma;
            v_idSerialMaxDuration := v_infoSeriale(i).SERIAL_ID;
        end if;
    END LOOP;

    -- colectam informatia pentru actori
    OPEN actors;
    FETCH actors bulk collect into v_infoActors;
    CLOSE actors;

    -- pentru fiecare serial vedem daca e egal cu cel aflat anterior
    -- daca da ii dam actualizam countActors
    -- TODO: intrebare, era mai bine sa fac cu left/right join si sa verific daca count ul e 0
    for i in v_infoActors.first..v_infoActors.last loop
        if v_infoActors(i).id = v_idSerialMaxDuration then
            v_foundActors := true;
            v_countActors := v_infoActors(i).nr;
        end if;
        end loop;

    if v_foundActors = false then
        RAISE NO_ACTORS_FOUND;
    end if;

    return v_countActors;

exception
    when NAME_NOT_FOUND then
        DBMS_OUTPUT.PUT_LINE('Nu exista tipul introdus');
        return -1;

    when NO_ACTORS_FOUND then
        DBMS_OUTPUT.PUT_LINE('Nu am gasit actori pentru datele cerute');
        return -1;
end;
/

-- Nu au fost gasiti actori
declare
    v_tip_subscriptie SUBSCRIPTIE.TIP%TYPE := 'basic';
begin
    DBMS_OUTPUT.PUT_LINE(durata_subscriptie(v_tip_subscriptie));
end;
/

-- Nu exista tipul introdus
declare
    v_tip_subscriptie SUBSCRIPTIE.TIP%TYPE := 'test';
begin
    DBMS_OUTPUT.PUT_LINE(durata_subscriptie(v_tip_subscriptie));
end;
/

-- Functioneaza corect
declare
    v_tip_subscriptie SUBSCRIPTIE.TIP%TYPE := 'ultimate';
begin
    DBMS_OUTPUT.PUT_LINE(durata_subscriptie(v_tip_subscriptie));
end;
/
-- =================================================================

--      ====== EX9 ======
-- ni se da porcela unui utilizator, aflati toti actorii la care se poate uita
CREATE OR REPLACE PROCEDURE actori_utilizator(porecla_utilizator UTILIZATOR.PORECLA%TYPE)
AS
    v_idUtilizator UTILIZATOR.UTILIZATOR_ID%TYPE;
    v_firstIdUtilizator UTILIZATOR.UTILIZATOR_ID%TYPE;
    v_actorFound boolean := false;

    -- distinct pentru ca un actor poate juca in mai multe filme
    CURSOR getActori(idUtilizator UTILIZATOR.UTILIZATOR_ID%TYPE) IS
        select DISTINCT NUME
        from ACTOR a
        -- TODO: full outer joins ???
        JOIN ROL_JUCAT rl on a.ACTOR_ID = rl.ACTOR_ID
        JOIN FILM f on rl.FILM_ID = f.FILM_ID
        JOIN SUBSCRIPTIE_FILM sf on f.FILM_ID = sf.FILM_ID
        JOIN SUBSCRIPTIE s on sf.SUBSCRIPTIE_ID = s.SUBSCRIPTIE_ID
        JOIN UTILIZATOR u on s.SUBSCRIPTIE_ID = u.SUBSCRIPTIE_ID
        WHERE u.UTILIZATOR_ID = idUtilizator;

    NO_ACTORS_FOUND EXCEPTION;

BEGIN
    DBMS_OUTPUT.PUT_LINE('UTILIZATORUL: ' || porecla_utilizator);

    -- ia id-ul utilizatorului cu porecla data | TOO_MANY_ROWS/NO_DATA_FOUND
        -- alt bloc in caz ca exista doi sau mai multi utilizatori cu aceeasi porecla
        -- daca se intampla asta il luam pe primul
    BEGIN
        select UTILIZATOR_ID
        into v_idUtilizator
        from UTILIZATOR
        where lower(porecla_utilizator) = lower(porecla);
    EXCEPTION
        when TOO_MANY_ROWS then
            SELECT UTILIZATOR_ID
            INTO v_firstIdUtilizator
            FROM (
                SELECT UTILIZATOR_ID
                FROM UTILIZATOR
                WHERE lower(porecla_utilizator) = lower(porecla)
                AND ROWNUM = 1
            );
            v_idUtilizator := v_firstIdUtilizator;
    end;

    -- daca trecem de toate verificarile afisam toti actorii utilizatorului
    for i in getActori(v_idUtilizator) loop
        v_actorFound := true;
        DBMS_OUTPUT.PUT_LINE('  ' || i.NUME);
        end loop;

    -- verificam daca am gasit actori in cursor
    if v_actorFound = false then RAISE NO_ACTORS_FOUND;
    end if;
exception
    when NO_DATA_FOUND then
        DBMS_OUTPUT.PUT_LINE('  Nu au fost gasiti utilizatori cu porecla data');

    when NO_ACTORS_FOUND then
        DBMS_OUTPUT.PUT_LINE('  Acest utilizator nu se poate uita la niciun film cu actori');
end;
/

-- TOO_MANY_ROWS
begin
    actori_utilizator('skpha');
end;

-- NO_DATA_FOUND
begin
    actori_utilizator('test');
end;

-- NO_ACTORS_FOUND
declare
    type porecle is table of UTILIZATOR.porecla%type index by pls_integer;
    v_porecleUtilizatori porecle;
begin
    /*select porecla
    bulk collect into v_porecleUtilizatori
    from UTILIZATOR;
    for i in v_porecleUtilizatori.first..v_porecleUtilizatori.last loop
        actori_utilizator(v_porecleUtilizatori(i));
        end loop;*/
    actori_utilizator('OnePiece');
end;
-- =================================================================

--      ====== EX10 ======
-- Trigger care sa nu ne lase sa inseram mai multe decat 6
CREATE OR REPLACE TRIGGER nr_maxim_subscriptii
    BEFORE INSERT ON SUBSCRIPTIE
DECLARE
    v_nrSubscriptii number(2);
BEGIN
    -- punem numarul subscriptiilor in variabila
    select count(*)
    into v_nrSubscriptii
    from SUBSCRIPTIE;

    -- daca sunt sase deja, aruncam eroarea
    if v_nrSubscriptii >= 6 then
        RAISE_APPLICATION_ERROR(-20001,'Numarul maxim de subscriptii a fost atins');
    end if;
end;
/

begin
    insert into SUBSCRIPTIE(subscriptie_id, tip, cost) values (99999,'BaSiC',99);
end;
/

drop trigger nr_maxim_subscriptii;
select count(*) from SUBSCRIPTIE;
delete from SUBSCRIPTIE where SUBSCRIPTIE_ID = 99999;
-- =================================================================

--      ====== EX11 ======
-- TODO: poate fac si pentru seriale, si pentru delete
create or replace type subscriptii as varray(6) of number(6);

CREATE OR REPLACE TRIGGER inserare_filme
    BEFORE INSERT
    ON SUBSCRIPTIE_FILM
    FOR EACH ROW
DECLARE
    v_tipuriSubscriptii subscriptii;
    v_subscriptieCurenta boolean := false;
BEGIN
    -- obtinem id-urile subscriptiilor in functie de cost
    -- asta pentru a le avea in ordinea ierarhica corecta
    select SUBSCRIPTIE_ID
    bulk collect into v_tipuriSubscriptii
    from SUBSCRIPTIE
    order by COST;

    for i in v_tipuriSubscriptii.first..v_tipuriSubscriptii.last loop
        DBMS_OUTPUT.PUT_LINE(v_tipuriSubscriptii(i));
        end loop;

    -- TODO: inserand in subscriptie film in trigger declansam iar trigger ul
        -- idei:
            -- coloana aditionala in SF sa vedem daca am inserat
            -- tabela aditionala cu id uri de filme care au fost deja inserate

    -- parcurgem toate subscriptiile
    for i in v_tipuriSubscriptii.first..v_tipuriSubscriptii.last loop
        -- daca anterior gasisem subscriptia inserata atunci o inseram si in restul
        if v_subscriptieCurenta = true then
            insert into SUBSCRIPTIE_FILM(subscriptie_film_id, film_id, subscriptie_id)
                    values (INCREMENTARE_film.nextval, :NEW.FILM_ID, v_tipuriSubscriptii(i));
        end if;

        if :NEW.SUBSCRIPTIE_ID = v_tipuriSubscriptii(i) then
            v_subscriptieCurenta := true;
        end if;
        end loop;
end;
/

select FILM_ID
from SUBSCRIPTIE_FILM
where FILM_ID = 999;

insert into SUBSCRIPTIE_FILM(subscriptie_film_id, film_id, subscriptie_id) values (INCREMENTARE_FILM.nextval,999,55245);
drop trigger inserare_filme;
-- =================================================================

--      ====== EX12 ======
create table audit_tabele (
    utilizator varchar2(30),
    nume_bazadate varchar2(50),
    eveniment varchar2(20),
    nume_obiect varchar2(30),
    data date
);

CREATE OR REPLACE TRIGGER trigger_audit
    after create or drop or alter on schema
BEGIN
    insert into audit_tabele values (
                                     sys.LOGIN_USER(),
                                     sys.DATABASE_NAME(),
                                     sys.SYSEVENT(),
                                     sys.DICTIONARY_OBJ_NAME(),
                                     sysdate
                                    );
end;
/

create table test (tip varchar2(20));
drop table test;

select * from audit_tabele;

drop trigger trigger_audit;
-- =================================================================

--      ====== EX13 ======
    -- TODO: make ex6 and 7 procedures
-- CREATE OR REPLACE PACKAGE pachet_filme AS

-- =================================================================