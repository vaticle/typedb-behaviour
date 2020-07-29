#
# Copyright (C) 2020 Grakn Labs
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

Feature: Recursion Resolution

  In some cases, the inferences made by a rule are used to trigger further inferences by the same rule.
  This test feature verifies that so-called recursive inference works as intended.

  Background: Set up keyspaces for resolution testing

    Given connection has been opened
    Given connection delete all keyspaces
    Given connection open sessions for keyspaces:
      | materialised |
      | reasoned     |
    Given materialised keyspace is named: materialised
    Given reasoned keyspace is named: reasoned
    Given for each session, graql define
      """
      define

      person sub entity,
        has name,
        plays friend,
        plays employee;

      company sub entity,
        has name,
        plays employer;

      place sub entity,
        has name,
        plays location-subordinate,
        plays location-superior;

      friendship sub relation,
        relates friend;

      employment sub relation,
        relates employee,
        relates employer;

      location-hierarchy sub relation,
        relates location-subordinate,
        relates location-superior;

      name sub attribute, value string;
      """


  # TODO: re-enable all steps when query is resolvable (currently takes too long)
  Scenario: the types of entities in inferred relations can be used to make further inferences
    Given for each session, graql define
      """
      define

      big-place sub place,
        plays big-location-subordinate,
        plays big-location-superior;

      big-location-hierarchy sub location-hierarchy,
        relates big-location-subordinate as location-subordinate,
        relates big-location-superior as location-superior;

      transitive-location sub rule,
      when {
        (location-subordinate: $x, location-superior: $y) isa location-hierarchy;
        (location-subordinate: $y, location-superior: $z) isa location-hierarchy;
      }, then {
        (location-subordinate: $x, location-superior: $z) isa location-hierarchy;
      };

      if-a-big-thing-is-in-a-big-place-then-its-a-big-location sub rule,
      when {
        $x isa big-place;
        $y isa big-place;
        (location-subordinate: $x, location-superior: $y) isa location-hierarchy;
      }, then {
        (big-location-subordinate: $x, big-location-superior: $y) isa big-location-hierarchy;
      };
      """
    Given for each session, graql insert
      """
      insert
      $x isa big-place, has name "Mount Kilimanjaro";
      $y isa place, has name "Tanzania";
      $z isa big-place, has name "Africa";

      (location-subordinate: $x, location-superior: $y) isa location-hierarchy;
      (location-subordinate: $y, location-superior: $z) isa location-hierarchy;
      """
    When materialised keyspace is completed
    Then for graql query
      """
      match (big-location-subordinate: $x, big-location-superior: $y) isa big-location-hierarchy; get;
      """
#    Then all answers are correct in reasoned keyspace
    Then answer size in reasoned keyspace is: 1
    Then materialised and reasoned keyspaces are the same size


  # TODO: re-enable all steps when resolvable (currently takes too long)
  Scenario: the types of inferred relations can be used to make further inferences
    Given for each session, graql define
      """
      define

      entity1 sub entity,
          plays role11,
          plays role12,
          plays role21,
          plays role22,
          plays role31,
          plays role32;

      relation1 sub relation,
          relates role11,
          relates role12;

      relation2 sub relation,
          relates role21,
          relates role22;

      relation3 sub relation,
          relates role31,
          relates role32;

      relation3-inference sub rule,
      when {
          (role11:$x, role12:$y) isa relation1;
          (role21:$y, role22:$z) isa relation2;
          (role11:$z, role12:$u) isa relation1;
      },
      then {
          (role31:$x, role32:$u) isa relation3;
      };

      relation2-transitivity sub rule,
      when {
          (role21:$x, role22:$y) isa relation2;
          (role21:$y, role22:$z) isa relation2;
      },
      then {
          (role21:$x, role22:$z) isa relation2;
      };
      """
    Given for each session, graql insert
      """
      insert

      $x isa entity1;
      $y isa entity1;
      $z isa entity1;
      $u isa entity1;
      $v isa entity1;
      $w isa entity1;
      $q isa entity1;

      (role11:$x, role12:$y) isa relation1;
      (role21:$y, role22:$z) isa relation2;
      (role21:$z, role22:$u) isa relation2;
      (role21:$u, role22:$v) isa relation2;
      (role21:$v, role22:$w) isa relation2;
      (role11:$w, role12:$q) isa relation1;
      """
    When materialised keyspace is completed
    Then for graql query
      """
      match (role31: $x, role32: $y) isa relation3; get;
      """
#    Then all answers are correct in reasoned keyspace
    Then answer size in reasoned keyspace is: 1
    Then materialised and reasoned keyspaces are the same size


  Scenario: circular rule dependencies can be resolved
    Given for each session, graql define
      """
      define

      entity1 sub entity,
          plays role11,
          plays role12,
          plays role21,
          plays role22,
          plays role31,
          plays role32;

      relation1 sub relation,
          relates role11,
          relates role12;

      relation2 sub relation,
          relates role21,
          relates role22;

      relation3 sub relation,
          relates role31,
          relates role32;

      relation-1-to-2 sub rule,
      when {
          (role11:$x, role12:$y) isa relation1;
      },
      then {
          (role21:$x, role22:$y) isa relation2;
      };

      relation-3-to-2 sub rule,
      when {
          (role31:$x, role32:$y) isa relation3;
      },
      then {
          (role21:$x, role22:$y) isa relation2;
      };

      relation-2-to-3 sub rule,
      when {
          (role21:$x, role22:$y) isa relation2;
      },
      then {
          (role31:$x, role32:$y) isa relation3;
      };
      """
    Given for each session, graql insert
      """
      insert

      $x isa entity1;
      $y isa entity1;

      (role11:$x, role12:$x) isa relation1;
      (role11:$x, role12:$y) isa relation1;
      """
    When materialised keyspace is completed
    Then for graql query
      """
      match (role31: $x, role32: $y) isa relation3; get;
      """
    Then all answers are correct in reasoned keyspace
    # Each of the two material relation1 instances should infer a single relation3 via 1-to-2 and 2-to-3
    Then answer size in reasoned keyspace is: 2
    Then for graql query
      """
      match (role21: $x, role22: $y) isa relation2; get;
      """
    Then all answers are correct in reasoned keyspace
    # Relation-3-to-2 should not make any additional inferences - it should merely assert that the relations exist
    Then answer size in reasoned keyspace is: 2
    Then materialised and reasoned keyspaces are the same size


  # TODO: re-enable all steps when we have a solution for materialisation of infinite graphs (#75)
  Scenario: when resolution produces an infinite stream of answers, limiting the answer size allows it to terminate
    Given for each session, graql define
      """
      define

      dream sub relation,
        relates dreamer,
        relates dream-subject,
        plays dream-subject;

      person plays dreamer, plays dream-subject;

      inception sub rule,
      when {
        $x isa person;
        $z (dreamer: $x, dream-subject: $y) isa dream;
      }, then {
        (dreamer: $x, dream-subject: $z) isa dream;
      };
      """
    Given for each session, graql insert
      """
      insert
      $x isa person, has name "Yusuf";
      # If only Yusuf didn't dream about himself...
      (dreamer: $x, dream-subject: $x) isa dream;
      """
#    When materialised keyspace is completed
    Then for graql query
      """
      match $x isa dream; get; limit 10;
      """
#    Then all answers are correct in reasoned keyspace
    Then answer size in reasoned keyspace is: 10
#    Then materialised and reasoned keyspaces are the same size


  # TODO: re-enable all steps when materialisation is possible (may be an infinite graph?) (#75)
  Scenario: when relations' and attributes' inferences are mutually recursive, the inferred concepts can be retrieved
    Given for each session, graql define
      """
      define

      word sub entity,
          plays subtype,
          plays supertype,
          plays prep,
          plays pobj,
          has name;

      f sub word;
      o sub word;

      pobj sub role;
      prep sub role;
      subtype sub role;
      supertype sub role;

      inheritance sub relation,
          relates supertype,
          relates subtype;

      pair sub relation,
          relates prep,
          relates pobj,
          has typ,
          has name;

      name sub attribute, value string;
      typ sub attribute, value string;

      inference-all-pairs sub rule,
      when {
          $x isa word;
          $y isa word;
          $x has name !== 'f';
          $y has name !== 'o';
      },
      then {
          (prep: $x, pobj: $y) isa pair;
      };

      inference-pairs-ff sub rule,
      when {
          $f isa f;
          (subtype: $prep, supertype: $f) isa inheritance;
          (subtype: $pobj, supertype: $f) isa inheritance;
          $p (prep: $prep, pobj: $pobj) isa pair;
      },
      then {
          $p has name 'ff';
      };

      inference-pairs-fo sub rule,
      when {
          $f isa f;
          $o isa o;
          (subtype: $prep, supertype: $f) isa inheritance;
          (subtype: $pobj, supertype: $o) isa inheritance;
          $p (prep: $prep, pobj: $pobj) isa pair;
      },
      then {
          $p has name 'fo';
      };
      """
    Given for each session, graql insert
      """
      insert

      $f isa f, has name "f";
      $o isa o, has name "o";

      $aa isa word, has name "aa";
      $bb isa word, has name "bb";
      $cc isa word, has name "cc";

      (supertype: $o, subtype: $aa) isa inheritance;
      (supertype: $o, subtype: $bb) isa inheritance;
      (supertype: $o, subtype: $cc) isa inheritance;

      $pp isa word, has name "pp";
      $qq isa word, has name "qq";
      $rr isa word, has name "rr";
      $rr2 isa word, has name "rr";

      (supertype: $f, subtype: $pp) isa inheritance;
      (supertype: $f, subtype: $qq) isa inheritance;
      (supertype: $f, subtype: $rr) isa inheritance;
      (supertype: $f, subtype: $rr2) isa inheritance;
      """
#    When materialised keyspace is completed
    Then for graql query
      """
      match $p isa pair, has name 'ff'; get;
      """
#    Then all answers are correct in reasoned keyspace
    Then answer size in reasoned keyspace is: 16
    Then for graql query
      """
      match $p isa pair; get;
      """
#    Then all answers are correct in reasoned keyspace
    Then answer size in reasoned keyspace is: 64
#    Then materialised and reasoned keyspaces are the same size


  Scenario: non-regular transitivity requiring iterative generation of tuples

    from Vieille - Recursive Axioms in Deductive Databases p. 192

    Given for each session, graql define
      """
      define

      entity2 sub entity,
        has index;

      R sub relation, relates R-role-A, relates R-role-B;
      entity2 plays R-role-A, plays R-role-B;

      E sub relation, relates E-role-A, relates E-role-B;
      entity2 plays E-role-A, plays E-role-B;

      F sub relation, relates F-role-A, relates F-role-B;
      entity2 plays F-role-A, plays F-role-B;

      G sub relation, relates G-role-A, relates G-role-B;
      entity2 plays G-role-A, plays G-role-B;

      H sub relation, relates H-role-A, relates H-role-B;
      entity2 plays H-role-A, plays H-role-B;

      index sub attribute, value string;

      rule-1 sub rule,
      when {
        (E-role-A: $x, E-role-B: $y) isa E;
      }, then {
        (R-role-A: $x, R-role-B: $y) isa R;
      };

      rule-2 sub rule,
      when {
        (F-role-A: $x, F-role-B: $t) isa F;
        (R-role-A: $t, R-role-B: $u) isa R;
        (G-role-A: $u, G-role-B: $v) isa G;
        (R-role-A: $v, R-role-B: $w) isa R;
        (H-role-A: $w, H-role-B: $y) isa H;
      }, then {
        (R-role-A: $x, R-role-B: $y) isa R;
      };
      """
    Given for each session, graql insert
      """
      insert

      $i isa entity2, has index "i";
      $j isa entity2, has index "j";
      $k isa entity2, has index "k";
      $l isa entity2, has index "l";
      $m isa entity2, has index "m";
      $n isa entity2, has index "n";
      $o isa entity2, has index "o";
      $p isa entity2, has index "p";
      $q isa entity2, has index "q";
      $r isa entity2, has index "r";
      $s isa entity2, has index "s";
      $t isa entity2, has index "t";
      $u isa entity2, has index "u";
      $v isa entity2, has index "v";

      (E-role-A: $i, E-role-B: $j) isa E;
      (E-role-A: $l, E-role-B: $m) isa E;
      (E-role-A: $n, E-role-B: $o) isa E;
      (E-role-A: $q, E-role-B: $r) isa E;
      (E-role-A: $t, E-role-B: $u) isa E;

      (F-role-A: $i, F-role-B: $i) isa F;
      (F-role-A: $i, F-role-B: $k) isa F;
      (F-role-A: $k, F-role-B: $l) isa F;

      (G-role-A: $m, G-role-B: $n) isa G;
      (G-role-A: $p, G-role-B: $q) isa G;
      (G-role-A: $s, G-role-B: $t) isa G;

      (H-role-A: $o, H-role-B: $p) isa H;
      (H-role-A: $r, H-role-B: $s) isa H;
      (H-role-A: $u, H-role-B: $v) isa H;
      """
    When materialised keyspace is completed
    Then for graql query
      """
      match
        ($x, $y) isa R;
        $x has index 'i';
      get $y;
      """
    Then all answers are correct in reasoned keyspace
    Then answer size in reasoned keyspace is: 3
    Then answer set is equivalent for graql query
      """
      match
        $y has index $ind;
        {$ind == 'j';} or {$ind == 's';} or {$ind == 'v';};
      get $y;
      """
    Then materialised and reasoned keyspaces are the same size


  Scenario: ancestor test

    from Bancilhon - An Amateur's Introduction to Recursive Query Processing Strategies p. 25

    Given for each session, graql define
      """
      define

      person sub entity,
        has name;

      Parent sub relation, relates parent, relates child;
      person plays parent, plays child;

      Ancestor sub relation, relates ancestor, relates descendant;
      person plays ancestor, plays descendant;

      name sub attribute, value string;

      rule-1 sub rule,
      when {
        (parent: $x, child: $z) isa Parent;
        (ancestor: $z, descendant: $y) isa Ancestor;
      }, then {
        (ancestor: $x, descendant: $y) isa Ancestor;
      };

      rule-2 sub rule,
      when {
        (parent: $x, child: $y) isa Parent;
      }, then {
        (ancestor: $x, descendant: $y) isa Ancestor;
      };
      """
    Given for each session, graql insert
      """
      insert

      $a isa person, has name 'a';
      $aa isa person, has name 'aa';
      $aaa isa person, has name 'aaa';
      $aab isa person, has name 'aab';
      $aaaa isa person, has name 'aaaa';
      $ab isa person, has name 'ab';
      $c isa person, has name 'c';
      $ca isa person, has name 'ca';

      (parent: $a, child: $aa) isa Parent;
      (parent: $a, child: $ab) isa Parent;
      (parent: $aa, child: $aaa) isa Parent;
      (parent: $aa, child: $aab) isa Parent;
      (parent: $aaa, child: $aaaa) isa Parent;
      (parent: $c, child: $ca) isa Parent;
      """
    When materialised keyspace is completed
    Then for graql query
      """
      match
        (ancestor: $X, descendant: $Y) isa Ancestor;
        $X has name 'aa';
        $Y has name $name;
      get $Y, $name;
      """
    Then all answers are correct in reasoned keyspace
    Then answer size in reasoned keyspace is: 3
    Then answer set is equivalent for graql query
      """
      match
        $Y isa person, has name $name;
        {$name == 'aaa';} or {$name == 'aab';} or {$name == 'aaaa';};
      get $Y, $name;
      """
    Then for graql query
      """
      match
        ($X, $Y) isa Ancestor;
        $X has name 'aa';
      get $Y;
      """
    Then all answers are correct in reasoned keyspace
    Then answer size in reasoned keyspace is: 4
    Then answer set is equivalent for graql query
      """
      match
        $Y isa person, has name $name;
        {$name == 'a';} or {$name == 'aaa';} or {$name == 'aab';} or {$name == 'aaaa';};
      get $Y;
      """
    Then for graql query
      """
      match
        (ancestor: $X, descendant: $Y) isa Ancestor;
      get;
      """
    Then all answers are correct in reasoned keyspace
    Then answer size in reasoned keyspace is: 10
    Then answer set is equivalent for graql query
      """
      match
        $Y isa person, has name $nameY;
        $X isa person, has name $nameX;
        {$nameX == 'a';$nameY == 'aa';} or {$nameX == 'a';$nameY == 'ab';} or
        {$nameX == 'a';$nameY == 'aaa';} or {$nameX == 'a';$nameY == 'aab';} or
        {$nameX == 'a';$nameY == 'aaaa';} or {$nameX == 'aa';$nameY == 'aaa';} or
        {$nameX == 'aa';$nameY == 'aab';} or {$nameX == 'aa';$nameY == 'aaaa';} or
        {$nameX == 'aaa';$nameY == 'aaaa';} or {$nameX == 'c';$nameY == 'ca';};
      get $X, $Y;
      """
    Then for graql query
      """
      match
        ($X, $Y) isa Ancestor;
      get;
      """
    Then all answers are correct in reasoned keyspace
    Then answer size in reasoned keyspace is: 20
    Then answer set is equivalent for graql query
      """
      match
        $Y isa person, has name $nameY;
        $X isa person, has name $nameX;
        {$nameX == 'a';$nameY == 'aa';} or
        {$nameX == 'a';$nameY == 'ab';} or {$nameX == 'a';$nameY == 'aaa';} or
        {$nameX == 'a';$nameY == 'aab';} or {$nameX == 'a';$nameY == 'aaaa';} or
        {$nameY == 'a';$nameX == 'aa';} or
        {$nameY == 'a';$nameX == 'ab';} or {$nameY == 'a';$nameX == 'aaa';} or
        {$nameY == 'a';$nameX == 'aab';} or {$nameY == 'a';$nameX == 'aaaa';} or

        {$nameX == 'aa';$nameY == 'aaa';} or {$nameX == 'aa';$nameY == 'aab';} or
        {$nameX == 'aa';$nameY == 'aaaa';} or
        {$nameY == 'aa';$nameX == 'aaa';} or {$nameY == 'aa';$nameX == 'aab';} or
        {$nameY == 'aa';$nameX == 'aaaa';} or

        {$nameX == 'aaa';$nameY == 'aaaa';} or
        {$nameY == 'aaa';$nameX == 'aaaa';} or

        {$nameX == 'c';$nameY == 'ca';} or
        {$nameY == 'c';$nameX == 'ca';};
      get $X, $Y;
      """
    Then materialised and reasoned keyspaces are the same size


  Scenario: ancestor-friend test

    from Vieille - Recursive Axioms in Deductive Databases (QSQ approach) p. 186

    Given for each session, graql define
      """
      define

      person sub entity,
          has name;

      Friend sub relation, relates friend;
      person plays friend, plays friend;

      Parent sub relation, relates parent, relates child;
      person plays parent, plays child;

      Ancestor-friend sub relation, relates ancestor, relates ancestor-friend;
      person plays ancestor, plays ancestor-friend;

      name sub attribute, value string;

      rule-1 sub rule,
      when {
        (friend: $x, friend: $y) isa Friend;
      }, then {
        (ancestor: $x, ancestor-friend: $y) isa Ancestor-friend;
      };

      rule-2 sub rule,
      when {
        (parent: $x, child: $z) isa Parent;
        (ancestor: $z, ancestor-friend: $y) isa Ancestor-friend;
      }, then {
        (ancestor: $x, ancestor-friend: $y) isa Ancestor-friend;
      };
      """
    Given for each session, graql insert
      """
      insert

      $a isa person, has name "a";
      $b isa person, has name "b";
      $c isa person, has name "c";
      $d isa person, has name "d";
      $g isa person, has name "g";

      (parent: $a, child: $b) isa Parent;
      (parent: $b, child: $c) isa Parent;
      (friend: $a, friend: $g) isa Friend;
      (friend: $c, friend: $d) isa Friend;
      """
    When materialised keyspace is completed
    Then for graql query
      """
      match
        (ancestor: $X, ancestor-friend: $Y) isa Ancestor-friend;
        $X has name 'a';
        $Y has name $name;
      get $Y;
      """
    Then all answers are correct in reasoned keyspace
    Then answer size in reasoned keyspace is: 2
    Then answer set is equivalent for graql query
      """
      match
        $Y has name $name;
        {$name == 'd';} or {$name == 'g';};
      get $Y;
      """
    And answer set is equivalent for graql query
      """
      match
        ($X, $Y) isa Ancestor-friend;
        $X has name 'a';
      get $Y;
      """
    Then for graql query
      """
      match
        (ancestor: $X, ancestor-friend: $Y) isa Ancestor-friend;
        $Y has name 'd';
      get $X;
      """
    Then all answers are correct in reasoned keyspace
    Then answer size in reasoned keyspace is: 3
    Then answer set is equivalent for graql query
      """
      match
        $X has name $name;
        {$name == 'a';} or {$name == 'b';} or {$name == 'c';};
      get $X;
      """
    And answer set is equivalent for graql query
      """
      match
        ($X, $Y) isa Ancestor-friend;
        $Y has name 'd';
      get $X;
      """
    Then materialised and reasoned keyspaces are the same size


  Scenario: same-generation test

    from Vieille - Recursive Query Processing: The power of logic p. 25

    Given for each session, graql define
      """
      define

      entity2 sub entity,
          has name;
      Human sub entity2;

      Parent sub relation, relates parent, relates child;
      entity2 plays parent, plays child;

      SameGen sub relation, relates SG-role;
      entity2 plays SG-role;

      name sub attribute, value string;

      rule-1 sub rule,
      when {
        $x isa Human;
      }, then {
        (SG-role: $x, SG-role: $x) isa SameGen;
      };

      rule-2 sub rule,
      when {
        (parent: $x, child: $u) isa Parent;
        (parent: $y, child: $v) isa Parent;
        (SG-role: $u, SG-role: $v) isa SameGen;
      }, then {
        (SG-role: $x, SG-role: $y) isa SameGen;
      };
      """
    Given for each session, graql insert
      """
      insert

      $a isa entity2, has name "a";
      $b isa entity2, has name "b";
      $c isa entity2, has name "c";
      $d isa Human, has name "d";
      $e isa entity2, has name "e";
      $f isa entity2, has name "f";
      $g isa entity2, has name "g";
      $h isa entity2, has name "h";

      (parent: $a, child: $b) isa Parent;
      (parent: $a, child: $c) isa Parent;

      (parent: $b, child: $d) isa Parent;
      (parent: $c, child: $d) isa Parent;
      (parent: $e, child: $d) isa Parent;

      (parent: $f, child: $e) isa Parent;

      #Extra data
      (parent: $g, child: $f) isa Parent;

      (parent: $h, child: $g) isa Parent;
      """
    When materialised keyspace is completed
    Then for graql query
      """
      match
        ($x, $y) isa SameGen;
        $x has name 'a';
      get $y;
      """
    Then all answers are correct in reasoned keyspace
    Then answer size in reasoned keyspace is: 2
    Then answer set is equivalent for graql query
      """
      match
        $y has name $name;
        {$name == 'f';} or {$name == 'a';};
      get $y;
      """
    Then materialised and reasoned keyspaces are the same size


  Scenario: TC test

    from Vieille - Recursive Query Processing: The power of logic p. 18

    Given for each session, graql define
      """
      define

      entity2 sub entity,
          has index;
      q sub entity2;

      N-TC sub relation, relates N-TC-roleB, relates N-TC-roleA;
      entity2 plays N-TC-roleB, plays N-TC-roleA;

      TC sub relation, relates TC-roleA, relates TC-roleB;
      entity2 plays TC-roleA, plays TC-roleB;

      P sub relation, relates P-roleA, relates P-roleB;
      entity2 plays P-roleA, plays P-roleB;

      index sub attribute, value string;

      rule-1 sub rule,
      when {
        $x isa q;
        (TC-roleA: $x, TC-roleB: $y) isa TC;
      }, then {
        (N-TC-roleA: $x, N-TC-roleB: $y) isa N-TC;
      };

      rule-2 sub rule,
      when {
        (P-roleA: $x, P-roleB: $y) isa P;
      }, then {
        (TC-roleA: $x, TC-roleB: $y) isa TC;
      };

      rule-3 sub rule,
      when {
        (P-roleA: $x, P-roleB: $z) isa P;
        (TC-roleA:$z, TC-roleB: $y) isa TC;
      }, then {
        (TC-roleA: $x, TC-roleB: $y) isa TC;
      };
      """
    Given for each session, graql insert
      """
      insert

      $a isa entity2, has index "a";
      $a1 isa entity2, has index "a1";
      $a2 isa q, has index "a2";

      (P-roleA: $a1, P-roleB: $a) isa P;
      (P-roleA: $a2, P-roleB: $a1) isa P;
      """
    When materialised keyspace is completed
    Then for graql query
      """
      match
        ($x, $y) isa N-TC;
        $y has index 'a';
      get $x;
      """
    Then all answers are correct in reasoned keyspace
    Then answer size in reasoned keyspace is: 1
    Then answer set is equivalent for graql query
      """
      match $x has index 'a2'; get;
      """
    Then materialised and reasoned keyspaces are the same size


  Scenario: given a directed graph, all pairs of vertices (x,y) such that y is reachable from x can be found

    test 5.2 from Green

    It defines a node configuration:

                /^\
    aa -> bb -> cc -> dd

    and finds all pairs (from, to) such that `to` is reachable from `from`.

    Given for each session, graql define
      """
      define

      indexable sub entity,
          has index;

      traversable sub indexable,
          plays from,
          plays to;

      vertex sub traversable;
      node sub traversable;

      link sub relation, relates from, relates to;
      indirect-link sub relation, relates from, relates to;
      reachable sub relation, relates from, relates to;
      unreachable sub relation, relates from, relates to;

      index sub attribute, value string;

      reachability-transitivityA sub rule,
      when {
          (from: $x, to: $y) isa link;
      }, then {
          (from: $x, to: $y) isa reachable;
      };

      reachability-transitivityB sub rule,
      when {
          (from: $x, to: $z) isa link;
          (from: $z, to: $y) isa reachable;
      }, then {
          (from: $x, to: $y) isa reachable;
      };

      indirect-link-rule sub rule,
      when {
          (from: $x, to: $y) isa reachable;
          not {(from: $x, to: $y) isa link;};
      }, then {
          (from: $x, to: $y) isa indirect-link;
      };

      unreachability-rule sub rule,
      when {
          $x isa vertex;
          $y isa vertex;
          not {(from: $x, to: $y) isa reachable;};
      }, then {
          (from: $x, to: $y) isa unreachable;
      };
      """
    Given for each session, graql insert
      """
      insert

      $aa isa node, has index "aa";
      $bb isa node, has index "bb";
      $cc isa node, has index "cc";
      $dd isa node, has index "dd";

      (from: $aa, to: $bb) isa link;
      (from: $bb, to: $cc) isa link;
      (from: $cc, to: $cc) isa link;
      (from: $cc, to: $dd) isa link;
      """
    When materialised keyspace is completed
    Then for graql query
      """
      match (from: $x, to: $y) isa reachable; get;
      """
    Then all answers are correct in reasoned keyspace
    Then answer size in reasoned keyspace is: 7
    Then answer set is equivalent for graql query
      """
      match
        $x has index $indX;" +
        $y has index $indY;" +
        {$indX == 'aa';$indY == 'bb';} or
        {$indX == 'bb';$indY == 'cc';} or
        {$indX == 'cc';$indY == 'cc';} or
        {$indX == 'cc';$indY == 'dd';} or
        {$indX == 'aa';$indY == 'cc';} or
        {$indX == 'bb';$indY == 'dd';} or
        {$indX == 'aa';$indY == 'dd';};
      get $x, $y;
      """
    Then materialised and reasoned keyspaces are the same size


  Scenario: given an undirected graph, all vertices connected to a given vertex can be found

    For this test, the graph looks like the following:

             /^\
    a -- b -- c -- d

    We find the set of vertices connected to 'a', which is in fact all of the vertices, including 'a' itself.

    Given for each session, graql define
      """
      define

      vertex sub entity,
        key index;

      link sub relation, relates coordinate;
      vertex plays coordinate;

      reachable sub link, relates coordinate;

      index sub attribute, value string;

      a-linked-point-is-reachable sub rule,
      when {
        ($x, $y) isa link;
      }, then {
        (coordinate: $x, coordinate: $y) isa reachable;
      };

      a-point-reachable-from-a-linked-point-is-reachable sub rule,
      when {
        ($x, $z) isa link;
        ($z, $y) isa reachable;
      }, then {
        (coordinate: $x, coordinate: $y) isa reachable;
      };
      """
    Given for each session, graql insert
      """
      insert

      $a isa vertex, has index "a";
      $b isa vertex, has index "b";
      $c isa vertex, has index "c";
      $d isa vertex, has index "d";

      (coordinate: $a, coordinate: $b) isa link;
      (coordinate: $b, coordinate: $c) isa link;
      (coordinate: $c, coordinate: $c) isa link;
      (coordinate: $c, coordinate: $d) isa link;
      """
    When materialised keyspace is completed
    Then for graql query
      """
      match
        ($x, $y) isa reachable;
        $x has index 'a';
      get $y;
      """
    Then all answers are correct in reasoned keyspace
    Then answer size in reasoned keyspace is: 4
    Then answer set is equivalent for graql query
      """
      match
        $y has index $indY;
        {$indY == 'a';} or {$indY == 'b';} or {$indY == 'c';} or {$indY == 'd';};
      get $y;
      """
    Then materialised and reasoned keyspaces are the same size


  Scenario: same-generation - Cao test

    test 6.6 from Cao p.76

    Given for each session, graql define
      """
      define

      person sub entity,
        has name;

      Parent sub relation, relates parent, relates child;
      person plays parent, plays child;

      Sibling sub relation, relates sibA, relates sibB;
      person plays sibA, plays sibB;

      SameGen sub relation, relates SG-role-A, relates SG-role-B;
      person plays SG-role-A, plays SG-role-B;

      name sub attribute, value string;

      rule-1 sub rule,
      when {
        (sibA: $x, sibB: $y) isa Sibling;
      }, then {
        (SG-role-A: $x, SG-role-B: $y) isa SameGen;
      };

      rule-2 sub rule,
      when {
        (parent: $x, child: $u) isa Parent;
        ($u, $v) isa SameGen;
        (parent: $y, child: $v) isa Parent;
      }, then {
        (SG-role-A: $x, SG-role-B: $y) isa SameGen;
      };

      rule-3 sub rule,
      when {
        (parent: $z, child: $x) isa Parent;
        (parent: $z, child: $y) isa Parent;
      }, then {
        (sibA: $x, sibB: $y) isa Sibling;
      };
      """
    Given for each session, graql insert
      """
      insert

      $ann isa person, has name "ann";
      $bill isa person, has name "bill";
      $john isa person, has name "john";
      $peter isa person, has name "peter";

      (parent: $john, child: $ann) isa Parent;
      (parent: $john, child: $peter) isa Parent;
      (parent: $john, child: $bill) isa Parent;
      """
    When materialised keyspace is completed
    Then for graql query
      """
      match
        ($x, $y) isa SameGen;
        $x has name 'ann';
      get $y;
      """
    Then all answers are correct in reasoned keyspace
    Then answer size in reasoned keyspace is: 3
    Then answer set is equivalent for graql query
      """
      match
        $y has name $name;
        {$name == 'ann';} or {$name == 'bill';} or {$name == 'peter';};
      get $y;
      """
    Then materialised and reasoned keyspaces are the same size


  Scenario: reverse same-generation test