--      ====== EX6 ======

-- pentru o subscriptie afisati toate filmele ei
-- + toti actorii fiecarui film

-- varray
create or replace type actori as varray(20) of varchar2(50);
DECLARE
    -- tablou indexat care retine numele filmelor
    type filme is table of FILM.denumire%type index by pls_integer;
    v_filme filme;

    -- tablou imbricat care retine id-ul filmelor
    type filme_id is table of ACTOR.nume%type;
    v_filme_id filme_id;

    -- varray care contine numele actorilor
    v_actori actori;

    v_nume_subscriptie SUBSCRIPTIE.tip%type := 'basic';
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
-- =================================================================

--      ====== EX7 ======
-- pentru fiecare Serial cu id-ul in (1,3,6) afisati numele tutor
-- episoadelor care apartin
declare
    v_id_ser SERIAL.serial_id%type;
    v_nume_ser SERIAL.denumire%type;
    v_nume_episod varchar2(50);
    v_areEpisod number(1) := 0;

    -- cursor clasic
    CURSOR seriale IS
        select SERIAL_ID, DENUMIRE
        from SERIAL
        WHERE SERIAL_ID IN (1,3,6);

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