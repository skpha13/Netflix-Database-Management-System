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