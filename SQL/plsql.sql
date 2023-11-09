-- pentru o subscriptie afisati toate filmele ei
-- + toti actorii fiecarui film
-- + toate rolurile fiecarui film

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
