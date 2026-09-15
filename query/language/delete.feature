# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

#noinspection CucumberUndefinedStep
Feature: TypeQL Delete Query

  Background: Open connection and create a simple extensible schema
    Given typedb starts
    Given connection opens with default authentication
    Given connection is open: true
    Given connection has 0 databases
    Given connection create database: typedb
    Given connection open schema transaction for database: typedb

    Given typeql schema query
      """
      define
      entity person,
        plays friendship:friend,
        plays employment:employee,
        owns name @key,
        owns email @card(0..),
        owns age @card(0..);
      entity company,
        plays employment:employer;
      relation friendship,
        relates friend @card(0..),
        owns ref @key;
      relation employment,
        relates employee,
        relates employer,
        owns ref @key;
      attribute name @independent, value string;
      attribute email @independent, value string;
      attribute ref @independent, value integer;
      attribute age @independent, value integer;
      """
    Given transaction commits

    Given connection open write transaction for database: typedb


  ##########
  # THINGS #
  ##########

  Scenario: when deleting multiple variables, they all get deleted
    Given get answers of typeql write query
      """
      insert
      $x isa person, has name "Alex";
      $y isa person, has name "Bob";
      $r isa friendship, links (friend: $x, friend: $y), has ref 0;
      $n isa name "John";
      """
    Given uniquely identify answer concepts
      | x             | y            | r         | n              |
      | key:name:Alex | key:name:Bob | key:ref:0 | attr:name:John |
    Given transaction commits
    Given connection open write transaction for database: typedb
    When typeql write query
      """
      match
        $x isa person, has name "Alex";
        $r isa friendship, has ref 0;
        $n isa name "John";
      delete
        $x; $r; $n;
      """
    Then transaction commits

    When connection open read transaction for database: typedb
    When get answers of typeql read query
      """
      match $x isa person;
      """
    Then uniquely identify answer concepts
      | x            |
      | key:name:Bob |
    When get answers of typeql read query
      """
      match $x isa friendship;
      """
    Then answer size is: 0
    When get answers of typeql read query
      """
      match $x isa name;
      """
    Then uniquely identify answer concepts
      | x              |
      | attr:name:Alex |
      | attr:name:Bob  |


  Scenario: an entity can be deleted
    Given get answers of typeql write query
      """
      insert
      $x isa person, has name "Alex";
      $y isa person, has name "Bob";
      $r isa friendship, links (friend: $x, friend: $y),
         has ref 0;
      $n isa name "John";
      """
    Then uniquely identify answer concepts
      | x             | y            | r         | n              |
      | key:name:Alex | key:name:Bob | key:ref:0 | attr:name:John |
    Given transaction commits
    Given connection open write transaction for database: typedb
    When typeql write query
      """
      match
        $r isa person, has name "Alex";
      delete
        $r;
      """
    Then transaction commits

    When connection open read transaction for database: typedb
    When get answers of typeql read query
      """
      match $x isa person;
      """
    Then uniquely identify answer concepts
      | x            |
      | key:name:Bob |


  Scenario: a relation can be deleted
    Given get answers of typeql write query
      """
      insert
      $x isa person, has name "Alex";
      $y isa person, has name "Bob";
      $r isa friendship, links (friend: $x, friend: $y),
         has ref 0;
      $n isa name "John";
      """
    Then uniquely identify answer concepts
      | x             | y            | r         | n              |
      | key:name:Alex | key:name:Bob | key:ref:0 | attr:name:John |
    Given transaction commits
    Given connection open write transaction for database: typedb
    When typeql write query
      """
      match
        $r isa friendship, has ref 0;
      delete
        $r;
      """
    Then transaction commits

    When connection open read transaction for database: typedb
    When get answers of typeql read query
      """
      match $x isa friendship;
      """
    Then answer size is: 0


  Scenario: an attribute can be deleted
    Given get answers of typeql write query
      """
      insert
      $n isa name "John";
      """
    Then uniquely identify answer concepts
      | n              |
      | attr:name:John |
    Given transaction commits
    Given connection open write transaction for database: typedb
    When typeql write query
      """
      match
        $r isa name "John";
      delete
        $r;
      """
    Then transaction commits

    When connection open read transaction for database: typedb
    When get answers of typeql read query
      """
      match $x isa name;
      """
    Then answer size is: 0


  Scenario: one delete statement can delete multiple things
    Given get answers of typeql write query
      """
      insert
      $a isa person, has name "Alice";
      $b isa person, has name "Barbara";
      """
    Then uniquely identify answer concepts
      | a              | b                |
      | key:name:Alice | key:name:Barbara |
    Given transaction commits
    Given connection open write transaction for database: typedb
    When typeql write query
      """
      match
      $p isa person;
      delete
      $p;
      """
    Then transaction commits

    When connection open read transaction for database: typedb
    When get answers of typeql read query
      """
      match $x isa person;
      """
    Then answer size is: 0


  # TODO: 3.x: Needs finer insert validation.
  @ignore
  Scenario: variable types can be used in deletes
    Given typeql write query
      """
      insert
      $x isa person, has name 'John';
      (friend: $x) isa friendship, has ref 0;
      $y isa person, has name 'Alice';
      (friend: $y) isa friendship, has ref 1;
      """
    Given transaction commits

    Given connection open write transaction for database: typedb
    Given typeql write query
      """
      match
      $p isa person, has name $n0; $n0 == "John";
      $r isa! $r-type ($p), has ref $r0; $r0 == 0;
      $p-type label person;
      delete
      $p;
      has $n0 of $p;
      $r;
      links ($p) of $r;
      """
    Given transaction commits

    Given connection open write transaction for database: typedb
    Given typeql write query
      """
      match
      $p isa person, has name $n0; $n0 "Alice";
      $r ($role-type: $p) isa! $r-type, has ref $r0; $r0 1;
      $p-type type person;
      $r-type type friendship, relates $role-type;
      delete
      $p has $n0;
      $p;
      links ($role-type: $p) of $r;
      $r has $r0;
      $r;
      """
    Given transaction commits

    When connection open read transaction for database: typedb
    When get answers of typeql read query
      """
      match
      $x isa person;
      $r isa friendship ($x);

      """
    Then answer size is: 0


  Scenario: instances of multiple attribute supertypes and subtypes can be deleted based on a match
    Given transaction closes
    Given connection open schema transaction for database: typedb
    Given typeql schema query
      """
      define
        email @independent;
        attribute encrypted-email sub email;
        attribute corporate-email sub encrypted-email;
      """
    Given typeql write query
      """
      insert
        $e1 isa email "bob@mail.com";
        $e2 isa email "bobbie1987@gmail.com";
        $e3 isa encrypted-email "b0b@bob.bob";
        $e4 isa corporate-email "bob@typedb.com";
      """
    Given transaction commits
    When connection open write transaction for database: typedb
    When typeql write query
      """
      match
        $e isa email;
      delete
        $e;
      """
    When get answers of typeql read query
      """
      match $e isa email;
      """
    Then answer size is: 0

    When typeql write query
      """
      insert
        $e1 isa email "bob@mail.com";
        $e2 isa email "bobbie1987@gmail.com";
        $e3 isa encrypted-email "b0b@bob.bob";
        $e4 isa corporate-email "bob@typedb.com";
      """
    When typeql write query
      """
      match
        $e isa encrypted-email;
      delete
        $e;
      """
    When get answers of typeql read query
      """
      match $e isa email;
      """
    Then uniquely identify answer concepts
      | e                                 |
      | attr:email:"bob@mail.com"         |
      | attr:email:"bobbie1987@gmail.com" |

    When typeql write query
      """
      match
        $e isa email;
      delete
        $e;
      """
    When typeql write query
      """
      insert
        $e1 isa email "bob@mail.com";
        $e2 isa email "bobbie1987@gmail.com";
        $e3 isa encrypted-email "b0b@bob.bob";
        $e4 isa corporate-email "bob@typedb.com";
      """
    When typeql write query
      """
      match
        $e isa corporate-email;
      delete
        $e;
      """
    When get answers of typeql read query
      """
      match $e isa email;
      """
    Then uniquely identify answer concepts
      | e                                  |
      | attr:email:"bob@mail.com"          |
      | attr:email:"bobbie1987@gmail.com"  |
      | attr:encrypted-email:"b0b@bob.bob" |
    Then transaction commits

  ###############
  # ROLEPLAYERS #
  ###############

  Scenario: deleting a role player from a relation using its role keeps the relation and removes the role player from it
    Given get answers of typeql write query
      """
      insert
      $x isa person, has name "Alex";
      $y isa person, has name "Bob";
      $z isa person, has name "Carrie";
      $r isa friendship (friend: $x, friend: $y, friend: $z),
         has ref 0;
      """
    Then uniquely identify answer concepts
      | x             | y            | z               | r         |
      | key:name:Alex | key:name:Bob | key:name:Carrie | key:ref:0 |
    Given transaction commits
    Given connection open write transaction for database: typedb
    When typeql write query
      """
      match
        $r isa friendship (friend: $x, friend: $y, friend: $z);
        $x isa person, has name "Alex";
        $y isa person, has name "Bob";
        $z isa person, has name "Carrie";
      delete
        links (friend: $x) of $r;
      """
    Then transaction commits

    When connection open write transaction for database: typedb
    When get answers of typeql read query
      """
      match $r isa friendship, links (friend: $x, friend: $y);
      select $x, $y;
      """
    Then uniquely identify answer concepts
      | x               | y               |
      | key:name:Bob    | key:name:Carrie |
      | key:name:Carrie | key:name:Bob    |


  Scenario: deleting an instance removes it from all relations
    Given get answers of typeql write query
      """
      insert
      $x isa person, has name "Alex";
      $y isa person, has name "Bob";
      $z isa person, has name "Carrie";
      $r isa friendship, links (friend: $x, friend: $y), has ref 1;
      $r2 isa friendship, links (friend: $x, friend: $z), has ref 2;
      """
    Then uniquely identify answer concepts
      | x             | y            | z               | r         | r2        |
      | key:name:Alex | key:name:Bob | key:name:Carrie | key:ref:1 | key:ref:2 |
    Given transaction commits
    When connection open write transaction for database: typedb
    When typeql write query
      """
      match
        $x isa person, has name "Alex";
      delete
        $x;
      """
    Then transaction commits

    When connection open read transaction for database: typedb
    When get answers of typeql read query
      """
      match $x isa person;
      """
    Then uniquely identify answer concepts
      | x               |
      | key:name:Bob    |
      | key:name:Carrie |
    When get answers of typeql read query
      """
      match $r isa friendship (friend: $x);
      """
    Then uniquely identify answer concepts
      | r         | x               |
      | key:ref:1 | key:name:Bob    |
      | key:ref:2 | key:name:Carrie |


  @ignore
  # TODO: 3.x: Bring back when we have lists
  Scenario: repeated role players can be deleted from a relation
    Given get answers of typeql write query
      """
      insert
      $x isa person, has name "Alex";
      $y isa person, has name "Bob";
      $r isa friendship (friend: $x, friend: $x, friend: $y), has ref 0;
      """
    Then uniquely identify answer concepts
      | x             | y            | r         |
      | key:name:Alex | key:name:Bob | key:ref:0 |
    Given transaction commits
    When connection open write transaction for database: typedb
    When typeql write query
      """
      match
        $r isa friendship (friend: $x, friend: $x);
      delete
        links (friend: $x, friend: $x) of $r;
      """
    Then transaction commits

    When connection open read transaction for database: typedb
    When get answers of typeql read query
      """
      match $r isa friendship (friend: $x);
      """
    Then uniquely identify answer concepts
      | r         | x            |
      | key:ref:0 | key:name:Bob |


  Scenario: The role player playing the specialized role can be deleted
    Given transaction closes

    Given connection open schema transaction for database: typedb
    Given typeql schema query
    """
    define
    relation internship sub employment, relates intern as employee;
    entity student sub person, plays internship:intern;
    """
    Given transaction commits

    Given connection open write transaction for database: typedb
    When typeql write query
    """
    insert
      $p0 isa person, has name "p0";
      $e0 isa employment, links (employee: $p0), has ref 0;
      $s1 isa student, has name "s1";
      $e1 isa employment, links (employee: $s1), has ref 1;
      $s2 isa student, has name "s2";
      $i2 isa internship, links (intern: $s2), has ref 2;
    """
    Then transaction commits

    Given connection open write transaction for database: typedb
    When typeql write query; fails with a message containing: "Left type 'internship' across constraint 'links' is not compatible with right type 'employment:employee'"
    """
    match
      $e isa employment, links (employee: $p);
    delete
      links (employee: $p) of $e;
    """

    Given connection open write transaction for database: typedb
    When typeql write query
    """
    match
      $e isa! employment, links (employee: $p);
    delete
      links (employee: $p) of $e;
    """
    When get answers of typeql read query
    """
    match $e isa employment, links (employee: $p);
    """
    Then uniquely identify answer concepts
      | e         | p           |
      | key:ref:2 | key:name:s2 |

    Then transaction commits

    Given connection open write transaction for database: typedb
    When typeql write query
    """
    match
      $e isa employment, links (intern: $p);
    delete
      links (intern: $p) of $e;
    """
    When get answers of typeql read query
    """
    match $e isa employment, links (employee: $p);
    """
    Then answer size is: 0
    Then transaction commits


  @ignore
  # TODO: 3.x: Bring back when we have lists ( this also fails because we don't have role-player de-duplication?)
  Scenario: when deleting multiple repeated role players from a relation, it removes the number you asked to delete
    Given get answers of typeql write query
      """
      insert
      $x isa person, has name "Alex";
      $y isa person, has name "Bob";
      $r isa friendship (friend: $x, friend: $x, friend: $x, friend: $y), has ref 0;
      """
    Then uniquely identify answer concepts
      | x             | y            | r         |
      | key:name:Alex | key:name:Bob | key:ref:0 |
    Given transaction commits
    When connection open write transaction for database: typedb
    When typeql write query
      """
      match
        $r isa friendship (friend: $x, friend: $x, friend: $x);
      delete
        links (friend: $x, friend: $x) of $r;
      """
    Then transaction commits

    When connection open read transaction for database: typedb
    When get answers of typeql read query
      """
      match $r isa friendship, links (friend: $x, friend: $y);
      """
    Then uniquely identify answer concepts
      | r         | x             | y             |
      | key:ref:0 | key:name:Bob  | key:name:Alex |
      | key:ref:0 | key:name:Alex | key:name:Bob  |


  @ignore
  # TODO: 3.x: Bring back when we have lists
  Scenario: when deleting repeated role players in multiple statements, it removes the total number you asked to delete
    Given get answers of typeql write query
      """
      insert
      $x isa person, has name "Alex";
      $y isa person, has name "Bob";
      $r isa friendship (friend: $x, friend: $x, friend: $x, friend: $y), has ref 0;
      """
    Then uniquely identify answer concepts
      | x             | y            | r         |
      | key:name:Alex | key:name:Bob | key:ref:0 |
    Given transaction commits
    When connection open write transaction for database: typedb
    When typeql write query
      """
      match
        $x isa person;
        $r isa friendship (friend: $x, friend: $x, friend: $x);
      delete
        links (friend: $x, friend: $x) of $r;
      """
    Then transaction commits

    When connection open read transaction for database: typedb
    When get answers of typeql read query
      """
      match $r isa friendship, links (friend: $x, friend: $y);
      """
    Then uniquely identify answer concepts
      | r         | x             | y             |
      | key:ref:0 | key:name:Bob  | key:name:Alex |
      | key:ref:0 | key:name:Alex | key:name:Bob  |


  @ignore
  # TODO: 3.x: Bring back when we have lists
  Scenario: when deleting one of the repeated role players from a relation, only one duplicate is removed
    Given get answers of typeql write query
      """
      insert
      $x isa person, has name "Alex";
      $y isa person, has name "Bob";
      $r isa friendship (friend: $x, friend: $x, friend: $y), has ref 0;
      """
    Then uniquely identify answer concepts
      | x             | y            | r         |
      | key:name:Alex | key:name:Bob | key:ref:0 |
    Given transaction commits
    When connection open write transaction for database: typedb
    When typeql write query
      """
      match
        $r isa friendship (friend: $x);
        $x isa person, has name "Alex";
      delete
        links (friend: $x) of $r;
      """
    Then transaction commits

    When connection open read transaction for database: typedb
    When get answers of typeql read query
      """
      match $r isa friendship, links (friend: $x, friend: $y);
      """
    Then uniquely identify answer concepts
      | r         | x             | y             |
      | key:ref:0 | key:name:Bob  | key:name:Alex |
      | key:ref:0 | key:name:Alex | key:name:Bob  |


  Scenario: deleting role players in multiple statements is allowed
    Given get answers of typeql write query
      """
      insert
      $x isa person, has name "Alex";
      $y isa person, has name "Bob";
      $z isa person, has name "Carrie";
      $r isa friendship (friend: $x, friend: $y, friend: $z), has ref 0;
      """
    Then uniquely identify answer concepts
      | x             | y            | z               | r         |
      | key:name:Alex | key:name:Bob | key:name:Carrie | key:ref:0 |
    Given transaction commits
    When connection open write transaction for database: typedb
    When typeql write query
      """
      match
        $r isa friendship (friend: $x, friend: $y, friend: $z);
        $x isa person, has name "Alex";
        $y isa person, has name "Bob";
        $z isa person, has name "Carrie";
      delete
        links (friend: $x) of $r;
        links (friend: $y) of $r;
      """
    Then transaction commits


  Scenario: when deleting overlapping answers, deletes are idempotent
    Given typeql write query
      """
      insert
      $x isa person, has name "Alex", has email "alex@email.com", has email "al@email.com", has email "a@email.com";
      $y isa person, has name "Bob";
      $z isa person, has name "Charlie";
      $r isa friendship (friend: $x, friend: $y, friend: $z), has ref 0;
      """
    Given transaction commits

    Given connection open write transaction for database: typedb
    Then typeql write query
      """
      match
        $r isa friendship, links (friend: $x, friend: $y);
      delete
        links (friend: $x, friend: $y) of $r;
      """
    Given transaction commits
    When connection open write transaction for database: typedb
    When get answers of typeql read query
      """
      match $r isa friendship, links (friend: $x, friend: $y);
      """
    Then answer size is: 0

    Then typeql write query
      """
      match
        $x has email $a, has email $b;
      delete
        has $a of $x;
        has $b of $x;
      """
    Given transaction commits
    When connection open write transaction for database: typedb
    When get answers of typeql read query
      """
      match $r has email $a, has email $b;
      """
    Then answer size is: 0

    Then typeql write query
      """
      match
        $x isa person;
        $y isa person;
      delete
        $x;
        $y;
      """
    Given transaction commits
    When connection open write transaction for database: typedb
    When get answers of typeql read query
      """
      match $x isa person; $y isa person;
      """
    Then answer size is: 0


  Scenario: deletes are idempotent when deleting uncommitted concepts
    Given get answers of typeql write query
      """
      insert
      $x isa person, has name "Alex";
      $y isa person, has name "Bob";
      $r isa friendship, links (friend: $x, friend: $y),
         has ref 0;
      $n isa name "John";
      """
    Then uniquely identify answer concepts
      | x             | y            | r         | n              |
      | key:name:Alex | key:name:Bob | key:ref:0 | attr:name:John |

    When typeql write query
      """
      match
        $r isa friendship, links ($x);
      delete
        $r;
      """
    Then transaction commits

    When connection open read transaction for database: typedb
    When get answers of typeql read query
      """
      match $x isa friendship;
      """
    Then answer size is: 0


  Scenario: when deleting incompatible ownerships or role players, an error is thrown
    Given typeql write query
      """
      insert
      $x isa person, has name "Alex";
      $y isa person, has name "Bob";
      $c isa company;
      $r isa friendship, links (friend: $x, friend: $y), has ref 0;
      $e isa employment (employee: $x, employer: $c), has ref 1;
      """
    Given transaction commits

    Given connection open write transaction for database: typedb
    Then typeql write query; fails
      """
      match
        $x isa person;
        $a isa ref;
      delete
        has $a of $x;
      """

    Given connection open write transaction for database: typedb
    Then typeql write query; fails
      """
      match
        $x isa person;
        $r isa friendship ($x);
      delete
        links (employee: $x) of $r;
      """

    Given connection open write transaction for database: typedb
    Then typeql write query; fails
      """
      match
        $x isa company;
        $r isa friendship;
      delete
        links (friend: $x) of $r;
      """


  Scenario: when all instances that play roles in a relation are deleted, the relation instance gets cleaned up
    Given get answers of typeql write query
      """
      insert
      $x isa person, has name "Alex";
      $y isa person, has name "Bob";
      $r isa friendship, links (friend: $x, friend: $y), has ref 0;
      """
    Then uniquely identify answer concepts
      | x             | y            | r         |
      | key:name:Alex | key:name:Bob | key:ref:0 |
    Given transaction commits
    When connection open write transaction for database: typedb
    When typeql write query
      """
      match
        $x isa person, has name "Alex";
        $y isa person, has name "Bob";
      delete
        $x;
        $y;
      """
    Then transaction commits

    When connection open read transaction for database: typedb
    When get answers of typeql read query
      """
      match $r isa friendship;
      """
    Then answer size is: 0


  Scenario: when the last role player is disassociated from a relation instance, the relation instance gets cleaned up
    Given get answers of typeql write query
      """
      insert
      $x isa person, has name "Alex";
      $y isa person, has name "Bob";
      $r isa friendship, links (friend: $x, friend: $y), has ref 0;
      """
    Then uniquely identify answer concepts
      | x             | y            | r         |
      | key:name:Alex | key:name:Bob | key:ref:0 |
    Given transaction commits
    When connection open write transaction for database: typedb
    When typeql write query
      """
      match
        $x isa person, has name "Alex";
        $y isa person, has name "Bob";
        $r isa friendship ($x, $y);
      delete
        links (friend: $x, friend: $y) of $r;
      """
    Then transaction commits

    When connection open read transaction for database: typedb
    When get answers of typeql read query
      """
      match $r isa friendship;
      """
    Then answer size is: 0


  Scenario: deleting a role player with a too-specific (downcasting) role errors
    Given transaction closes
    Given connection open schema transaction for database: typedb
    Given typeql schema query
      """
      define
      relation special-friendship sub friendship,
        relates special-friend as friend;
      """
    Given transaction commits

    Given connection open write transaction for database: typedb
    When typeql write query
      """
      insert
      $x isa person, has name "Alex";
      $y isa person, has name "Bob";
      $r isa friendship, links (friend: $x, friend: $y), has ref 0;
      """
    Then transaction commits

    When connection open write transaction for database: typedb
    Then typeql write query; fails
      """
      match
        $x isa person, has name "Alex";
        $y isa person, has name "Bob";
        $r isa friendship, links (friend: $x, friend: $y);
      delete
        links (special-friend: $x) of $r;
      """


  Scenario: Matching & deleting a links constraint a supertype of the actual role-type labels does nothing.
    # TODO: Eventually, stronger insert validation can catch this.
    Given transaction closes
    Given connection open schema transaction for database: typedb
    Given typeql schema query
       """
        define
          relation internship sub employment, relates intern as employee;
          entity student sub person, plays internship:intern;
       """
    Given transaction commits
    Given connection open write transaction for database: typedb
    When typeql write query
       """
       insert
        $s2 isa student, has name "s2";
        $i2 isa internship, links (intern: $s2), has ref 2;
       """
    Given transaction commits

    Given connection open write transaction for database: typedb
    When get answers of typeql read query
    """
    match
      $e isa internship, links (intern: $p);
    """
    Then answer size is: 1
    When typeql write query; fails with a message containing: "Left type 'internship' across constraint 'links' is not compatible with right type 'employment:employee'"
      """
      match
        $e isa employment, links (employee: $p);
      delete
        links (employee: $p) of $e;
      """


#  Even when a $role variable matches multiple roles (will always match 'role' unless constrained)
#  We only delete role player edges until the 'match' is no longer satisfied.
#
#  **Sometimes this means multiple repeated role players will be unassigned **
#
#  For example
#
#  // concrete instance:  $r isa directed-by (production: $x, production: $x, production: $x, director: $y);
#  match $r isa directed-by ($role1: $x, director: $y); $type sub work;
#  delete links ($role1: $x) of $r;
#
#  First, we will match '$role1' = ROLE meta role. Using this answer we will remove a single $x from $r via the 'production'.
#  Next, we will match '$role1' = WORK role, and we delete another 'production' player. This repeats again for $role='production'.
  Scenario: when deleting repeated role players with a single variable role, both repetitions are removed
    Given transaction closes
    Given connection open schema transaction for database: typedb
    Given typeql schema query
      """
      define
      relation ship-crew, relates captain, relates navigator, relates chef, owns ref @key;
      person plays ship-crew:captain, plays ship-crew:navigator, plays ship-crew:chef;
      """
    Given transaction commits

    Given connection open write transaction for database: typedb
    Given typeql write query
      """
      insert
      $x isa person, has name "Cook";
      $y isa person, has name "Joshua";
      $r isa ship-crew (captain: $x, chef: $y), has ref 0;
      """
    Given transaction commits

    When connection open write transaction for database: typedb
    When get answers of typeql read query
      """
      match $rel isa ship-crew (chef: $p);
      """
    Then uniquely identify answer concepts
      | rel       | p               |
      | key:ref:0 | key:name:Joshua |
    When typeql write query
      """
      match
        $r isa ship-crew ($role1: $x, captain: $y);
      delete
        links ($role1: $x) of $r;
      """
    Then transaction commits

    When connection open read transaction for database: typedb
    When get answers of typeql read query
      """
      match $rel isa ship-crew (chef: $p);
      """
    Then answer size is: 0


  ########################
  # ATTRIBUTE OWNERSHIPS #
  ########################

  Scenario: deleting an attribute instance also deletes its ownerships
    Given transaction closes
    Given connection open schema transaction for database: typedb
    Given typeql schema query
      """
      define
      attribute age, value integer;
      person owns age;
      """
    Given transaction commits

    Given connection open write transaction for database: typedb
    Given typeql write query
      """
      insert
      $x isa person, has name "Anna", has age 18;
      """
    Given transaction commits

    When connection open write transaction for database: typedb
    When get answers of typeql read query
      """
      match $x has age 18;
      """
    Then uniquely identify answer concepts
      | x             |
      | key:name:Anna |
    When typeql write query
      """
      match
        $x isa age 18;
      delete
        $x;
      """
    Then transaction commits

    When connection open read transaction for database: typedb
    When get answers of typeql read query
      """
      match $x has age 18;
      """
    Then answer size is: 0


  Scenario: attempting to delete an attribute ownership with a redeclared isa errors
    Given transaction closes
    Given connection open schema transaction for database: typedb
    Given typeql schema query
      """
      define
      attribute lastname, value string;
      entity person, owns lastname;
      """
    Given transaction commits

    Given connection open write transaction for database: typedb
    Given get answers of typeql write query
      """
      insert
      $x isa person,
        has lastname "Smith",
        has name "Alex";
      $y isa person,
        has lastname "Smith",
        has name "John";
      """
    Then uniquely identify answer concepts
      | x             | y             |
      | key:name:Alex | key:name:John |
    Given transaction commits
    When connection open write transaction for database: typedb
    When typeql write query; parsing fails
      """
      match
        $x isa person, has lastname $n, has name "Alex";
        $n == "Smith";
      delete
        has lastname $n of $x;
      """


  Scenario: an attribute deletion using anonymous thing variables errors
    Given typeql write query
      """
      insert
      $x isa person,
        has email "alex@abc.com",
        has name "Alex";
      """
    Given transaction commits
    When connection open write transaction for database: typedb
    When typeql write query; parsing fails
      """
      match
        $x isa person, has email "alex@abc.com";
      delete
        has name "Alex" of $x;
      """


  Scenario: deleting the owner of an attribute also deletes the attribute ownership
    Given transaction closes
    Given connection open schema transaction for database: typedb
    Given typeql schema query
      """
      define
      attribute timespan, value integer;
      friendship owns timespan;
      """
    Given transaction commits

    Given connection open write transaction for database: typedb
    Given typeql write query
      """
      insert
      $x isa person, has name "Tom";
      $y isa person, has name "Jerry";
      $r isa friendship, links (friend: $x, friend: $y), has ref 0, has timespan 1000;
      """
    Given transaction commits

    Given connection open write transaction for database: typedb
    When get answers of typeql read query
      """
      match $x has timespan $d;
      """
    Then uniquely identify answer concepts
      | x         | d                  |
      | key:ref:0 | attr:timespan:1000 |
    When typeql write query
      """
      match
        $r isa friendship;
      delete
        $r;
      """
    Then transaction commits

    When connection open read transaction for database: typedb
    When get answers of typeql read query
      """
      match $x has timespan $d;
      """
    Then answer size is: 0


  Scenario: deleting the last roleplayer in a relation deletes both the relation and its attribute ownerships
    Given transaction closes
    Given connection open schema transaction for database: typedb
    Given typeql schema query
      """
      define
      attribute timespan, value integer;
      friendship owns timespan;
      """
    Given transaction commits

    Given connection open write transaction for database: typedb
    Given typeql write query
      """
      insert
      $x isa person, has name "Emma";
      $r isa friendship (friend: $x), has ref 0, has timespan 1000;
      """
    Given transaction commits

    When connection open write transaction for database: typedb
    When get answers of typeql read query
      """
      match $x has timespan $d;
      """
    Then uniquely identify answer concepts
      | x         | d                  |
      | key:ref:0 | attr:timespan:1000 |
    When typeql write query
      """
      match
        $r isa friendship (friend: $x);
      delete
        links (friend: $x) of $r;
      """
    Then transaction commits

    When connection open read transaction for database: typedb
    When get answers of typeql read query
      """
      match $x has timespan $d;
      """
    Then answer size is: 0
    When get answers of typeql read query
      """
      match $r isa friendship;
      """
    Then answer size is: 0


  Scenario: an error is thrown when deleting the ownership of a non-existent attribute type
    Then typeql write query; fails
      """
      match
        $x has diameter $val;
      delete
        has $val of $x;
      """


  Scenario: has can be deleted for instances of multiple attribute supertypes and subtypes
    Given transaction closes
    Given connection open schema transaction for database: typedb
    Given typeql schema query
      """
      define
        person owns encrypted-email @card(0..), owns corporate-email;
        attribute encrypted-email sub email;
        attribute corporate-email sub encrypted-email;
      """
    Given typeql write query
      """
      insert
        $p isa person,
          has name "Bob",
          has email "bob@mail.com",
          has email "bobbie1987@gmail.com",
          has encrypted-email "b0b@bob.bob",
          has corporate-email "bob@typedb.com";
      """
    Given transaction commits
    When connection open write transaction for database: typedb
    When typeql write query
      """
      match
        $p has email $e;
      delete
        has $e of $p;
      """
    When get answers of typeql read query
      """
      match $_ has email $e;
      """
    Then answer size is: 0

    When typeql write query
      """
      match
        $p isa person;
      delete
        $p;
      """
    When typeql write query
      """
      insert
        $p isa person,
          has name "Bob",
          has email "bob@mail.com",
          has email "bobbie1987@gmail.com",
          has encrypted-email "b0b@bob.bob",
          has corporate-email "bob@typedb.com";
      """
    When typeql write query
      """
      match
        $p has encrypted-email $e;
      delete
        has $e of $p;
      """
    When get answers of typeql read query
      """
      match $_ has email $e;
      """
    Then uniquely identify answer concepts
      | e                                 |
      | attr:email:"bob@mail.com"         |
      | attr:email:"bobbie1987@gmail.com" |

    When typeql write query
      """
      match
        $p isa person;
      delete
        $p;
      """
    When typeql write query
      """
      insert
        $p isa person,
          has name "Bob",
          has email "bob@mail.com",
          has email "bobbie1987@gmail.com",
          has encrypted-email "b0b@bob.bob",
          has corporate-email "bob@typedb.com";
      """
    When typeql write query
      """
      match
        $p has corporate-email $e;
      delete
        has $e of $p;
      """
    When get answers of typeql read query
      """
      match $_ has email $e;
      """
    Then uniquely identify answer concepts
      | e                                  |
      | attr:email:"bob@mail.com"          |
      | attr:email:"bobbie1987@gmail.com"  |
      | attr:encrypted-email:"b0b@bob.bob" |
    Then transaction commits


  Scenario: has can be deleted based on a match of supertypes of owners and attributes without prior has matching, skipping non-existing instances
    Given transaction closes
    Given connection open schema transaction for database: typedb
    Given typeql schema query
      """
      define
        entity root-person @abstract, owns internet-address @card(0..);
        person @abstract, sub root-person, owns email @card(0..);
        entity safe-person sub person, owns encrypted-email @card(0..);

        attribute internet-address @abstract;
        attribute email @abstract, sub internet-address;
        attribute encrypted-email sub email;
      """
    Given transaction commits

    When connection open schema transaction for database: typedb
    When typeql write query
      """
      insert $p isa safe-person, has name "Alice", has encrypted-email "al1ce@typedb.com";
      """
    When get answers of typeql read query
      """
      match $_ has name $n, has encrypted-email $_;
      """
    Then uniquely identify answer concepts
      | n               |
      | attr:name:Alice |
    When get answers of typeql write query
      """
      match
        $p isa root-person;
        $e isa email;
      delete
        has $e of $p;
      """
    Then uniquely identify answer concepts
      | e                                     | p              |
      | attr:encrypted-email:al1ce@typedb.com | key:name:Alice |
    When get answers of typeql read query
      """
      match $_ has name $n, has encrypted-email $_;
      """
    Then answer size is: 0
    When typeql write query
      """
      insert $p isa safe-person, has name "Bob", has encrypted-email "b0b@typedb.com";
      """
    When get answers of typeql read query
      """
      match $_ has name $n, has encrypted-email $_;
      """
    Then uniquely identify answer concepts
      | n             |
      | attr:name:Bob |
    When get answers of typeql write query
      """
      match
        $p isa root-person;
        $e isa email;
      delete
        has $e of $p;
      """
    # email is independent, so the attributes are not cleaned up
    Then uniquely identify answer concepts
      | e                                     | p              |
      | attr:encrypted-email:al1ce@typedb.com | key:name:Alice |
      | attr:encrypted-email:al1ce@typedb.com | key:name:Bob   |
      | attr:encrypted-email:b0b@typedb.com   | key:name:Alice |
      | attr:encrypted-email:b0b@typedb.com   | key:name:Bob   |
    When get answers of typeql read query
      """
      match $_ has name $n, has encrypted-email $_;
      """
    Then answer size is: 0
    When typeql schema query
      """
      undefine @independent from email;
      """
    When typeql write query
      """
      insert $p isa safe-person, has name "Charlie", has encrypted-email "4arl1e@typedb.com";
      """
    When get answers of typeql read query
      """
      match $_ has name $n, has encrypted-email $_;
      """
    Then uniquely identify answer concepts
      | n                 |
      | attr:name:Charlie |
    When get answers of typeql write query
      """
      match
        $p isa root-person;
        $e isa email;
      delete
        has $e of $p;
      """
    Then uniquely identify answer concepts
      | e                                      | p                |
      | attr:encrypted-email:4arl1e@typedb.com | key:name:Alice   |
      | attr:encrypted-email:4arl1e@typedb.com | key:name:Bob     |
      | attr:encrypted-email:4arl1e@typedb.com | key:name:Charlie |
    When get answers of typeql read query
      """
      match $_ has name $n, has encrypted-email $_;
      """
    Then answer size is: 0
    When transaction closes

    When connection open schema transaction for database: typedb
    When typeql schema query
      """
      undefine @independent from email;
      """
    When transaction commits

    When connection open write transaction for database: typedb
    When typeql write query
      """
      insert $p isa safe-person, has name "Alice", has encrypted-email "al1ce@typedb.com";
      """
    When get answers of typeql read query
      """
      match $_ has name $n, has encrypted-email $_;
      """
    Then uniquely identify answer concepts
      | n               |
      | attr:name:Alice |
    When get answers of typeql write query
      """
      match
        $p isa person;
        $e isa internet-address;
      delete
        has $e of $p;
      """
    Then uniquely identify answer concepts
      | e                                     | p              |
      | attr:encrypted-email:al1ce@typedb.com | key:name:Alice |
    When get answers of typeql read query
      """
      match $_ has name $n, has encrypted-email $_;
      """
    Then answer size is: 0
    When typeql write query
      """
      insert $p isa safe-person, has name "Bob", has encrypted-email "b0b@typedb.com";
      """
    When get answers of typeql read query
      """
      match $_ has name $n, has encrypted-email $_;
      """
    Then uniquely identify answer concepts
      | n             |
      | attr:name:Bob |
    When get answers of typeql write query
      """
      match
        $p isa safe-person;
        $e isa internet-address;
      delete
        has $e of $p;
      """
    Then uniquely identify answer concepts
      | e                                   | p              |
      | attr:encrypted-email:b0b@typedb.com | key:name:Alice |
      | attr:encrypted-email:b0b@typedb.com | key:name:Bob   |
    When get answers of typeql read query
      """
      match $_ has name $n, has encrypted-email $_;
      """
    Then answer size is: 0


  Scenario: has can be deleted for instances of multiple attribute supertypes and subtypes for multiple owner subtypes
    Given transaction closes
    Given connection open schema transaction for database: typedb
    Given typeql schema query
      """
      define
        entity root-person @abstract, owns internet-address @card(0..);
        person sub root-person, owns email @card(0..);
        entity safe-person sub person, owns encrypted-email @card(0..), owns personal-encrypted-email;
        entity worker sub safe-person, owns corporate-email;

        attribute internet-address @abstract;
        attribute email sub internet-address;
        attribute encrypted-email sub email;
        attribute corporate-email sub encrypted-email;
        attribute personal-encrypted-email sub encrypted-email;
      """
    Given typeql write query
      """
      insert
        $alice isa person,
          has name "Alice",
          has email "alice@mail.com";
        $bob isa safe-person,
          has name "Bob",
          has encrypted-email "bob@gmail.com";
        $charlie isa safe-person,
          has name "Charlie",
          has email "charlie@mail.com",
          has encrypted-email "charlie@gmail.com",
          has personal-encrypted-email "charlie@charlie.com";
        $david isa worker,
          has name "David",
          has corporate-email "david@typedb.com";
        $elon isa worker,
          has name "Elon",
          has email "elon@mail.com",
          has encrypted-email "elon@gmail.com",
          has personal-encrypted-email "elon@elon.com",
          has corporate-email "elon@typedb.com";
      """
    Given transaction commits

    When connection open write transaction for database: typedb
    When typeql write query
      """
      match
        $p isa root-person, has name "Alice", has email $e;
      delete
        has $e of $p;
      """
    When get answers of typeql read query
      """
      match $_ has name $n, has email $_;
      """
    Then uniquely identify answer concepts
      | n                 |
      | attr:name:Bob     |
      | attr:name:Charlie |
      | attr:name:David   |
      | attr:name:Elon    |
    When transaction closes

    When connection open write transaction for database: typedb
    When typeql write query
      """
      match
        $p isa root-person, has name "Alice", has internet-address $e;
      delete
        has $e of $p;
      """
    When get answers of typeql read query
      """
      match $_ has name $n, has email $_;
      """
    Then uniquely identify answer concepts
      | n                 |
      | attr:name:Bob     |
      | attr:name:Charlie |
      | attr:name:David   |
      | attr:name:Elon    |
    When transaction closes

    When connection open write transaction for database: typedb
    When typeql write query
      """
      match
        $p isa root-person, has name "Bob", has internet-address $e;
      delete
        has $e of $p;
      """
    When get answers of typeql read query
      """
      match $_ has name $n, has email $_;
      """
    Then uniquely identify answer concepts
      | n                 |
      | attr:name:Alice   |
      | attr:name:Charlie |
      | attr:name:David   |
      | attr:name:Elon    |
    When transaction closes

    When connection open write transaction for database: typedb
    When typeql write query
      """
      match
        $p isa root-person, has name "Charlie", has internet-address $e;
      delete
        has $e of $p;
      """
    When get answers of typeql read query
      """
      match $_ has name $n, has email $_;
      """
    Then uniquely identify answer concepts
      | n               |
      | attr:name:Alice |
      | attr:name:Bob   |
      | attr:name:David |
      | attr:name:Elon  |
    When transaction closes

    When connection open write transaction for database: typedb
    When typeql write query
      """
      match
        $p isa root-person, has name "David", has internet-address $e;
      delete
        has $e of $p;
      """
    When get answers of typeql read query
      """
      match $_ has name $n, has email $_;
      """
    Then uniquely identify answer concepts
      | n                 |
      | attr:name:Alice   |
      | attr:name:Bob     |
      | attr:name:Charlie |
      | attr:name:Elon    |
    When transaction closes

    When connection open write transaction for database: typedb
    When typeql write query
      """
      match
        $p isa root-person, has name "Elon", has internet-address $e;
      delete
        has $e of $p;
      """
    When get answers of typeql read query
      """
      match $_ has name $n, has email $_;
      """
    Then uniquely identify answer concepts
      | n                 |
      | attr:name:Alice   |
      | attr:name:Bob     |
      | attr:name:Charlie |
      | attr:name:David   |
    When transaction closes

    When connection open write transaction for database: typedb
    When typeql write query
      """
      match
        $p isa root-person, has name "Alice", has encrypted-email $e;
      delete
        has $e of $p;
      """
    When get answers of typeql read query
      """
      match $_ has name $n, has email $_;
      """
    Then uniquely identify answer concepts
      | n                 |
      | attr:name:Alice   |
      | attr:name:Bob     |
      | attr:name:Charlie |
      | attr:name:David   |
      | attr:name:Elon    |
    When transaction closes

    When connection open write transaction for database: typedb
    When typeql write query
      """
      match
        $p isa worker, has name "Alice", has encrypted-email $e;
      delete
        has $e of $p;
      """
    When get answers of typeql read query
      """
      match $_ has name $n, has email $_;
      """
    Then uniquely identify answer concepts
      | n                 |
      | attr:name:Alice   |
      | attr:name:Bob     |
      | attr:name:Charlie |
      | attr:name:David   |
      | attr:name:Elon    |
    When transaction closes

    When connection open write transaction for database: typedb
    When typeql write query
      """
      match
        $p isa person, has internet-address $e;
      delete
        has $e of $p;
      """
    When get answers of typeql read query
      """
      match $_ has name $n, has email $_;
      """
    Then answer size is: 0
    When transaction closes

    When connection open write transaction for database: typedb
    When typeql write query
      """
      match
        $p isa person, has email $e;
      delete
        has $e of $p;
      """
    When get answers of typeql read query
      """
      match $_ has name $n, has email $_;
      """
    Then answer size is: 0
    When transaction closes

    When connection open write transaction for database: typedb
    When get answers of typeql write query
      """
      match
        $p isa person, has encrypted-email $e;
      delete
        has $e of $p;
      select $p;
      """
    # The number of encrypted-emails
    Then answer size is: 7
    When get answers of typeql read query
      """
      match $_ has name $n, has email $_;
      """
    Then uniquely identify answer concepts
      | n                 |
      | attr:name:Alice   |
      | attr:name:Charlie |
      | attr:name:Elon    |
    When transaction closes

    When connection open write transaction for database: typedb
    When get answers of typeql write query
      """
      match
        $p isa person, has personal-encrypted-email $e;
      delete
        has $e of $p;
      select $p;
      """
    Then uniquely identify answer concepts
      | p                |
      | key:name:Charlie |
      | key:name:Elon    |
    When get answers of typeql read query
      """
      match $_ has name $n, has email $_;
      """
    Then uniquely identify answer concepts
      | n                 |
      | attr:name:Alice   |
      | attr:name:Bob     |
      | attr:name:Charlie |
      | attr:name:David   |
      | attr:name:Elon    |
    When transaction closes

    When connection open write transaction for database: typedb
    When get answers of typeql write query
      """
      match
        $p isa person, has corporate-email $e;
      delete
        has $e of $p;
      select $p;
      """
    Then uniquely identify answer concepts
      | p              |
      | key:name:David |
      | key:name:Elon  |
    When get answers of typeql read query
      """
      match $_ has name $n, has email $_;
      """
    Then uniquely identify answer concepts
      | n                 |
      | attr:name:Alice   |
      | attr:name:Bob     |
      | attr:name:Charlie |
      | attr:name:Elon    |
    When transaction closes

    When connection open write transaction for database: typedb
    When get answers of typeql write query
      """
      match
        $p isa worker, has email $e;
      delete
        has $e of $p;
      select $p;
      """
    # The number of emails of workers
    Then answer size is: 5
    When get answers of typeql read query
      """
      match $_ has name $n, has email $_;
      """
    Then uniquely identify answer concepts
      | n                 |
      | attr:name:Alice   |
      | attr:name:Bob     |
      | attr:name:Charlie |
    When transaction closes

    When connection open write transaction for database: typedb
    When get answers of typeql write query
      """
      match
        $p isa safe-person, has email $e;
      delete
        has $e of $p;
      select $p;
      """
    # The number of emails of safe-persons
    Then answer size is: 9
    When get answers of typeql read query
      """
      match $_ has name $n, has email $_;
      """
    Then uniquely identify answer concepts
      | n               |
      | attr:name:Alice |
    When transaction closes

    When connection open write transaction for database: typedb
    When get answers of typeql write query
      """
      match
        $p isa safe-person, has $e;
        $e isa email;
      delete
        has $e of $p;
      select $p;
      """
    # The number of emails of safe-persons
    Then answer size is: 9
    When get answers of typeql read query
      """
      match $_ has name $n, has email $_;
      """
    Then uniquely identify answer concepts
      | n               |
      | attr:name:Alice |
    When transaction closes

    When connection open write transaction for database: typedb
    When get answers of typeql write query
      """
      match
        $p isa safe-person, has $e;
        $e isa corporate-email;
      delete
        has $e of $p;
      select $p;
      """
    Then uniquely identify answer concepts
      | p              |
      | key:name:David |
      | key:name:Elon  |
    When get answers of typeql read query
      """
      match $_ has name $n, has email $_;
      """
    Then uniquely identify answer concepts
      | n                 |
      | attr:name:Alice   |
      | attr:name:Bob     |
      | attr:name:Charlie |
      | attr:name:Elon    |
    When transaction closes

    When connection open write transaction for database: typedb
    Then typeql write query; fails with a message containing: "Left type 'safe-person' across constraint 'has' is not compatible with right type 'corporate-email'"
      """
      match
        $p isa safe-person;
        $e isa corporate-email;
      delete
        has $e of $p;
      """

    When connection open write transaction for database: typedb
    When get answers of typeql write query
      """
      match
        $p isa worker;
        $e isa corporate-email;
      delete
        has $e of $p;
      select $p;
      """
    # permutations of worker (2) - corporate-email (2)
    Then answer size is: 4
    When get answers of typeql read query
      """
      match $_ has name $n, has email $_;
      """
    Then uniquely identify answer concepts
      | n                 |
      | attr:name:Alice   |
      | attr:name:Bob     |
      | attr:name:Charlie |
      | attr:name:Elon    |
    When transaction closes

    When connection open write transaction for database: typedb
    When get answers of typeql write query
      """
      match
        $p isa worker;
        $e isa encrypted-email;
      delete
        has $e of $p;
      select $p;
      """
    # permutations of worker (2) - encrypted email (7)
    Then answer size is: 14
    When get answers of typeql read query
      """
      match $_ has name $n, has email $_;
      """
    Then uniquely identify answer concepts
      | n                 |
      | attr:name:Alice   |
      | attr:name:Bob     |
      | attr:name:Charlie |
      | attr:name:Elon    |
    When transaction closes

    When connection open write transaction for database: typedb
    When get answers of typeql write query
      """
      match
        $p isa worker;
        $e isa email;
      delete
        has $e of $p;
      select $p;
      """
    # permutations of worker (2) - email (10)
    Then answer size is: 20
    When get answers of typeql read query
      """
      match $_ has name $n, has email $_;
      """
    Then uniquely identify answer concepts
      | n                 |
      | attr:name:Alice   |
      | attr:name:Bob     |
      | attr:name:Charlie |
    When transaction closes

    When connection open write transaction for database: typedb
    When get answers of typeql write query
      """
      match
        $p isa worker;
        $e isa internet-address;
      delete
        has $e of $p;
      select $p;
      """
    # permutations of worker (2) - internet-address (10)
    Then answer size is: 20
    When get answers of typeql read query
      """
      match $_ has name $n, has email $_;
      """
    Then uniquely identify answer concepts
      | n                 |
      | attr:name:Alice   |
      | attr:name:Bob     |
      | attr:name:Charlie |


  Scenario Outline: not independent attributes are always hidden after queries if owners are lost: <mode>
    Given transaction closes
    Given connection open schema transaction for database: typedb
    Given typeql schema query
      """
      undefine @independent from email;
      """
    Given transaction commits

    When connection open write transaction for database: typedb
    When typeql write query
      """
      insert $a isa email "<deleted-email>";
      """
    When get answers of typeql read query
      """
      match $a isa email;
      """
    Then answer size is: 0

    When typeql write query
      """
      insert $p isa person, has name "<deleted-name>", has email "<deleted-email>";
      """
    When get answers of typeql read query
      """
      match $a isa email;
      """
    Then uniquely identify answer concepts
      | a                            |
      | attr:email:"<deleted-email>" |

    When typeql write query
      """
      match $p isa person, has name "<deleted-name>", has email $e;
      delete has $e of $p;
      """
    When get answers of typeql read query
      """
      match $a isa email;
      """
    Then answer size is: 0
    When transaction commits

    When connection open write transaction for database: typedb
    When typeql write query
      """
      match
        $a isa person, has name "<deleted-name>";
      insert
        $a has email "<deleted-email>";
        $b isa person, has name "Bob", has email "bob@typedb.com";
      """
    When get answers of typeql read query
      """
      match $a isa email;
      """
    Then uniquely identify answer concepts
      | a                            |
      | attr:email:"bob@typedb.com"  |
      | attr:email:"<deleted-email>" |
    When get answers of typeql read query
      """
      match $_ has email $a;
      """
    Then uniquely identify answer concepts
      | a                            |
      | attr:email:"bob@typedb.com"  |
      | attr:email:"<deleted-email>" |

    When typeql write query
      """
      match $p isa person, has email $e;
      delete has $e of $p;
      """
    When get answers of typeql read query
      """
      match $a isa email;
      """
    Then answer size is: 0
    When get answers of typeql read query
      """
      match $_ has email $a;
      """
    Then answer size is: 0
    When transaction commits

    When connection open write transaction for database: typedb
    When get answers of typeql read query
      """
      match $a isa email;
      """
    Then answer size is: 0
    When get answers of typeql read query
      """
      match $_ has email $a;
      """
    Then answer size is: 0
    When typeql write query
      """
      match
        $a isa person, has name "<deleted-name>";
      delete
        $a;
      """
    When transaction commits

    When connection open write transaction for database: typedb
    When typeql write query
      """
      match
        $b isa person, has name "Bob";
      insert
        $b has email "bob@typedb.com";
        $a isa person, has name "<deleted-name>", has email "<deleted-email>";
      """
    When get answers of typeql read query
      """
      match $a isa email;
      """
    Then uniquely identify answer concepts
      | a                            |
      | attr:email:"bob@typedb.com"  |
      | attr:email:"<deleted-email>" |
    When get answers of typeql read query
      """
      match $_ has email $a;
      """
    Then uniquely identify answer concepts
      | a                            |
      | attr:email:"bob@typedb.com"  |
      | attr:email:"<deleted-email>" |

    When typeql write query
      """
      match $p isa person, has email $e;
      delete has $e of $p;
      """
    When get answers of typeql read query
      """
      match $a isa email;
      """
    Then answer size is: 0
    When get answers of typeql read query
      """
      match $_ has email $a;
      """
    Then answer size is: 0
    When transaction commits

    When connection open write transaction for database: typedb
    When get answers of typeql read query
      """
      match $a isa email;
      """
    Then answer size is: 0
    When get answers of typeql read query
      """
      match $_ has email $a;
      """
    Then answer size is: 0

    When typeql write query
      """
      match
        $b isa person, has name "Bob";
        $a isa person, has name "<deleted-name>";
      insert
        $b has email "bob@typedb.com";
        $a has email "<deleted-email>";
      """
    When get answers of typeql read query
      """
      match $a isa email;
      """
    Then uniquely identify answer concepts
      | a                            |
      | attr:email:"bob@typedb.com"  |
      | attr:email:"<deleted-email>" |
    When get answers of typeql read query
      """
      match $_ has email $a;
      """
    Then uniquely identify answer concepts
      | a                            |
      | attr:email:"bob@typedb.com"  |
      | attr:email:"<deleted-email>" |
    When typeql write query
      """
      match $p isa person, has name "<deleted-name>", has email $e;
      delete has $e of $p;
      """
    When get answers of typeql read query
      """
      match $a isa email;
      """
    Then uniquely identify answer concepts
      | a                           |
      | attr:email:"bob@typedb.com" |
    When get answers of typeql read query
      """
      match $_ has email $a;
      """
    Then uniquely identify answer concepts
      | a                           |
      | attr:email:"bob@typedb.com" |
    When transaction commits

    When connection open write transaction for database: typedb
    When get answers of typeql read query
      """
      match $a isa email;
      """
    Then uniquely identify answer concepts
      | a                           |
      | attr:email:"bob@typedb.com" |
    When get answers of typeql read query
      """
      match $_ has email $a;
      """
    Then uniquely identify answer concepts
      | a                           |
      | attr:email:"bob@typedb.com" |

    When typeql write query
      """
      match
        $a isa person, has name "<deleted-name>";
      insert
        $a has email "<deleted-email>";
      """
    When get answers of typeql read query
      """
      match $a isa email;
      """
    Then uniquely identify answer concepts
      | a                            |
      | attr:email:"bob@typedb.com"  |
      | attr:email:"<deleted-email>" |
    When get answers of typeql read query
      """
      match $_ has email $a;
      """
    Then uniquely identify answer concepts
      | a                            |
      | attr:email:"bob@typedb.com"  |
      | attr:email:"<deleted-email>" |
    When transaction commits

    When connection open write transaction for database: typedb
    When get answers of typeql read query
      """
      match $a isa email;
      """
    Then uniquely identify answer concepts
      | a                            |
      | attr:email:"bob@typedb.com"  |
      | attr:email:"<deleted-email>" |
    When get answers of typeql read query
      """
      match $_ has email $a;
      """
    Then uniquely identify answer concepts
      | a                            |
      | attr:email:"bob@typedb.com"  |
      | attr:email:"<deleted-email>" |

    When typeql write query
      """
      match $p isa person, has name "<deleted-name>", has email $e;
      delete has $e of $p;
      """
    When get answers of typeql read query
      """
      match $a isa email;
      """
    Then uniquely identify answer concepts
      | a                           |
      | attr:email:"bob@typedb.com" |
    When get answers of typeql read query
      """
      match $_ has email $a;
      """
    Then uniquely identify answer concepts
      | a                           |
      | attr:email:"bob@typedb.com" |
    When transaction commits

    When connection open write transaction for database: typedb
    When typeql write query
      """
      match $p isa person, has name "<deleted-name>", has email $e;
      delete has $e of $p;
      """
    When get answers of typeql read query
      """
      match $a isa email;
      """
    Then uniquely identify answer concepts
      | a                           |
      | attr:email:"bob@typedb.com" |
    When get answers of typeql read query
      """
      match $_ has email $a;
      """
    Then uniquely identify answer concepts
      | a                           |
      | attr:email:"bob@typedb.com" |

    When typeql write query
      """
      match
        $a isa person, has name "<deleted-name>";
      insert
        $a has email "<deleted-email>";
      """
    When get answers of typeql read query
      """
      match $a isa email;
      """
    Then uniquely identify answer concepts
      | a                            |
      | attr:email:"bob@typedb.com"  |
      | attr:email:"<deleted-email>" |
    When get answers of typeql read query
      """
      match $_ has email $a;
      """
    Then uniquely identify answer concepts
      | a                            |
      | attr:email:"bob@typedb.com"  |
      | attr:email:"<deleted-email>" |
    When transaction commits

    When connection open write transaction for database: typedb
    When get answers of typeql read query
      """
      match $a isa email;
      """
    Then uniquely identify answer concepts
      | a                            |
      | attr:email:"bob@typedb.com"  |
      | attr:email:"<deleted-email>" |
    When get answers of typeql read query
      """
      match $_ has email $a;
      """
    Then uniquely identify answer concepts
      | a                            |
      | attr:email:"bob@typedb.com"  |
      | attr:email:"<deleted-email>" |

    When typeql write query
      """
      match
        $a isa person, has name "<deleted-name>";
      insert
        $a has email "<deleted-email>";
      """
    When get answers of typeql read query
      """
      match $a isa email;
      """
    Then uniquely identify answer concepts
      | a                            |
      | attr:email:"bob@typedb.com"  |
      | attr:email:"<deleted-email>" |
    When get answers of typeql read query
      """
      match $_ has email $a;
      """
    Then uniquely identify answer concepts
      | a                            |
      | attr:email:"bob@typedb.com"  |
      | attr:email:"<deleted-email>" |
    When transaction commits

    When connection open write transaction for database: typedb
    When get answers of typeql read query
      """
      match $a isa email;
      """
    Then uniquely identify answer concepts
      | a                            |
      | attr:email:"bob@typedb.com"  |
      | attr:email:"<deleted-email>" |
    When get answers of typeql read query
      """
      match $_ has email $a;
      """
    Then uniquely identify answer concepts
      | a                            |
      | attr:email:"bob@typedb.com"  |
      | attr:email:"<deleted-email>" |

    When typeql write query
      """
      match
        $a isa person, has name "<deleted-name>";
      insert
        $a has email "<deleted-email>";
      """
    When get answers of typeql read query
      """
      match $a isa email;
      """
    Then uniquely identify answer concepts
      | a                            |
      | attr:email:"bob@typedb.com"  |
      | attr:email:"<deleted-email>" |
    When get answers of typeql read query
      """
      match $_ has email $a;
      """
    Then uniquely identify answer concepts
      | a                            |
      | attr:email:"bob@typedb.com"  |
      | attr:email:"<deleted-email>" |

    When typeql write query
      """
      match $p isa person, has name "<deleted-name>", has email $e;
      delete has $e of $p;
      """
    When get answers of typeql read query
      """
      match $a isa email;
      """
    Then uniquely identify answer concepts
      | a                           |
      | attr:email:"bob@typedb.com" |
    When get answers of typeql read query
      """
      match $_ has email $a;
      """
    Then uniquely identify answer concepts
      | a                           |
      | attr:email:"bob@typedb.com" |
    When transaction commits

    When connection open write transaction for database: typedb
    When get answers of typeql read query
      """
      match $a isa email;
      """
    Then uniquely identify answer concepts
      | a                           |
      | attr:email:"bob@typedb.com" |
    When get answers of typeql read query
      """
      match $_ has email $a;
      """
    Then uniquely identify answer concepts
      | a                           |
      | attr:email:"bob@typedb.com" |

    When typeql write query
      """
      match
        $a isa person, has name "<deleted-name>";
      insert
        $a has email "<deleted-email>";
      """
    When get answers of typeql read query
      """
      match $a isa email;
      """
    Then uniquely identify answer concepts
      | a                            |
      | attr:email:"bob@typedb.com"  |
      | attr:email:"<deleted-email>" |
    When get answers of typeql read query
      """
      match $_ has email $a;
      """
    Then uniquely identify answer concepts
      | a                            |
      | attr:email:"bob@typedb.com"  |
      | attr:email:"<deleted-email>" |
    When transaction commits

    When connection open write transaction for database: typedb
    When get answers of typeql read query
      """
      match $a isa email;
      """
    Then uniquely identify answer concepts
      | a                            |
      | attr:email:"bob@typedb.com"  |
      | attr:email:"<deleted-email>" |
    When get answers of typeql read query
      """
      match $_ has email $a;
      """
    Then uniquely identify answer concepts
      | a                            |
      | attr:email:"bob@typedb.com"  |
      | attr:email:"<deleted-email>" |

    When typeql write query
      """
      match $p isa person, has name "<deleted-name>", has email $e;
      delete has $e of $p;
      """
    When get answers of typeql read query
      """
      match $a isa email;
      """
    Then uniquely identify answer concepts
      | a                           |
      | attr:email:"bob@typedb.com" |
    When get answers of typeql read query
      """
      match $_ has email $a;
      """
    Then uniquely identify answer concepts
      | a                           |
      | attr:email:"bob@typedb.com" |

    When typeql write query
      """
      match
        $a isa person, has name "<deleted-name>";
      insert
        $a has email "<deleted-email>";
      """
    When get answers of typeql read query
      """
      match $a isa email;
      """
    Then uniquely identify answer concepts
      | a                            |
      | attr:email:"bob@typedb.com"  |
      | attr:email:"<deleted-email>" |
    When get answers of typeql read query
      """
      match $_ has email $a;
      """
    Then uniquely identify answer concepts
      | a                            |
      | attr:email:"bob@typedb.com"  |
      | attr:email:"<deleted-email>" |
    When transaction commits

    When connection open read transaction for database: typedb
    When get answers of typeql read query
      """
      match $a isa email;
      """
    Then uniquely identify answer concepts
      | a                            |
      | attr:email:"bob@typedb.com"  |
      | attr:email:"<deleted-email>" |
    When get answers of typeql read query
      """
      match $_ has email $a;
      """
    Then uniquely identify answer concepts
      | a                            |
      | attr:email:"bob@typedb.com"  |
      | attr:email:"<deleted-email>" |

    Examples:
      | mode                         | deleted-name | deleted-email      |
      | alphabetically smaller value | Alice        | alice@typedb.com   |
      | alphabetically bigger value  | Charlie      | charlie@typedb.com |


  Scenario: Non-existent ownerships are ignored by the delete.
    Given typeql write query
      """
      insert
      $x isa person, has name "Tom";
      $y isa person, has name "Jerry";
      """
    Given transaction commits

    Given connection open write transaction for database: typedb
    When get answers of typeql write query
      """
      match
        $x isa person; $n isa name;
      delete
        has $n of $x;
      """
    Then answer size is: 4


  ####################
  # COMPLEX PATTERNS #
  ####################

  # TODO: 3.x: Bring back when we have lists, because (friend: $x, friend: $x)
  @ignore
  Scenario: deletion of a complex pattern
    Given transaction closes
    Given connection open schema transaction for database: typedb
    Given typeql schema query
      """
      define
      attribute lastname, value string;
      entity person, owns lastname;
      """
    Given transaction commits

    Given connection open write transaction for database: typedb
    Given typeql write query
      """
      insert
      $x isa person,
        has lastname "Smith",
        has name "Alex";
      $y isa person,
        has lastname "Smith",
        has name "John";
      $r isa friendship, links (friend: $x, friend: $y), has ref 1;
      $r1 isa friendship, links (friend: $x, friend: $y), has ref 2;
      $reflexive isa friendship (friend: $x, friend: $x), has ref 3;
      """
    Given transaction commits

    When connection open write transaction for database: typedb
    When typeql write query
      """
      match
        $x isa person, has name "Alex", has lastname $n;
        $y isa person, has name "John", has lastname $n;
        $refl isa friendship (friend: $x, friend: $x), has ref 3;
        $f1 isa friendship, links (friend: $x, friend: $y), has ref 1;
      delete
        has $n of $x;
        links (friend: $x) of $refl;
        $f1;
      """
    Then transaction commits

    When connection open read transaction for database: typedb
    When get answers of typeql read query
      """
      match $f isa friendship (friend: $x);
      """
    Then uniquely identify answer concepts
      | f         | x             |
      | key:ref:2 | key:name:Alex |
      | key:ref:2 | key:name:John |
      | key:ref:3 | key:name:Alex |
    When get answers of typeql read query
      """
      match $n isa name;
      """
    Then uniquely identify answer concepts
      | n              |
      | attr:name:John |
      | attr:name:Alex |
    When get answers of typeql read query
      """
      match $x isa person, has lastname $n;
      """
    Then uniquely identify answer concepts
      | x             | n                   |
      | key:name:John | attr:lastname:Smith |


  # TODO: 3.x: Bring back when we have lists (friend: $x, friend: $x)
  @ignore
  Scenario: deleting everything in a complex pattern
    Given transaction closes
    Given connection open schema transaction for database: typedb
    Given typeql schema query
      """
      define
      attribute lastname, value string;
      entity person, owns lastname;
      """
    Given transaction commits

    Given connection open write transaction for database: typedb
    Given typeql write query
      """
      insert
      $x isa person,
        has lastname "Smith",
        has name "Alex";
      $y isa person,
        has lastname "Smith",
        has name "John";
      $r isa friendship, links (friend: $x, friend: $y), has ref 1;
      $r1 isa friendship, links (friend: $x, friend: $y), has ref 2;
      $reflexive isa friendship (friend: $x, friend: $x), has ref 3;
      """
    Given transaction commits

    When connection open write transaction for database: typedb
    When typeql write query
      """
      match
        $x isa person, has name "Alex", has lastname $n;
        $y isa person, has name "John", has lastname $n;
        $refl isa friendship (friend: $x, friend: $x), has ref $r1; $r1 == 3;
        $f1 isa friendship, links (friend: $x, friend: $y), has ref $r2; $r2 == 1;
      delete
        $x; $y; $refl; $f1;
        has $n of $x;
        has $n of $y;
        links (friend: $x, friend: $x) of $refl;
        has $r1 of $refl;
        links (friend: $x, friend: $y) of $f1;
        has $r2 of $f1;
      """
    Then transaction commits

    When connection open read transaction for database: typedb
    When get answers of typeql read query
      """
      match $x isa person, has lastname $n;
      """
    Then answer size is: 0


  ##############
  # EDGE CASES #
  ##############

  Scenario: deleting a variable not in the query errors, even if there were no matches
    Then typeql write query; fails
      """
      match $x isa person; delete $n;
      """


  Scenario: deleting a has ownership @key errors on commit
    Given typeql write query
      """
      insert
      $x isa person, has name "Alex";
      """
    Given transaction commits

    When connection open write transaction for database: typedb
    Then typeql write query
      """
      match
        $x isa person, has name $n;
        $n == "Alex";
      delete
        has $n of $x;
      """
    Then transaction commits; fails


  Scenario: deleting an attribute instance that is owned as a has @key errors
    Given typeql write query
      """
      insert
      $x isa person, has name "Tatyana";
      """
    Given transaction commits

    When connection open write transaction for database: typedb
    When get answers of typeql read query
      """
      match $x isa name;
      """
    Then uniquely identify answer concepts
      | x                 |
      | attr:name:Tatyana |
    Then typeql write query
      """
      match
        $x isa name "Tatyana";
      delete
        $x;
      """
    Then transaction commits; fails


  Scenario: deleting a type errors
    Then typeql write query; fails
      """
      match
        $x label person;
      delete
        $x;
      """


  Scenario: deleting an anonymous variable errors
    Then typeql write query; fails with a message containing: "anonymous"
      """
      delete
        has $_ of $_;
      """

    When connection open write transaction for database: typedb
    Then typeql write query; fails with a message containing: "anonymous"
      """
      insert
        $p isa person, has name "John";
      delete
        has $_ of $p;
      """

    When connection open write transaction for database: typedb
    Then typeql write query; fails with a message containing: "anonymous"
      """
      insert
        $n isa name "John";
      delete
        has $n of $_;
      """


  Scenario: Concept deletions do not cause trouble for constraint deletions in the same stage referencing that concept
    Given typeql write query
    """
    insert $john isa person, has name "John";
    insert $jane isa person, has name "Jane";
    """
    Given transaction commits
    When connection open write transaction for database: typedb
    Then typeql write query
      """
      match $x isa person; $y isa person;
       { $x has name "John"; $y has name "Jane"; } or
       { $x has name "Jane"; $y has name "John"; };
       $x has name $n;
       delete
        has $n of $x;
        $y;
      """
    Then transaction commits


  Scenario: an optional binding is deleted
    Given typeql write query
    """
    insert
      $john isa person, has name "John";
      $jane isa person, has name "Jane", has email "jane@doe.com";
    """
    When get answers of typeql write query
    """
    match $p isa person, has name $name; try { $p has email $email; };
    delete try { isset $email; $email; };
    """
    Then uniquely identify answer concepts
      | p             | name           |
      | key:name:John | attr:name:John |
      | key:name:Jane | attr:name:Jane |
    Then transaction commits
    Then connection open write transaction for database: typedb
    Then get answers of typeql read query
    """
    match $p isa person, has email $email;
    """
    Then answer size is: 0


  Scenario: a has edge depending on an optional binding is deleted
    Given typeql write query
    """
    insert
      $john isa person, has name "John";
      $jane isa person, has name "Jane", has email "jane@doe.com";
    """
    When get answers of typeql write query
    """
    match $p isa person, has name $name; try { $p has email $email; };
    delete try { isset $email; has $email of $p; };
    """
    Then uniquely identify answer concepts
      | p             | name           | email                   |
      | key:name:John | attr:name:John | none                    |
      | key:name:Jane | attr:name:Jane | attr:email:jane@doe.com |
    Then transaction commits
    Then connection open write transaction for database: typedb
    Then get answers of typeql read query
    """
    match $p isa person, has email $email;
    """
    Then answer size is: 0


  Scenario: multiple edges in a single try block are only deleted when all optional variables are bound
    Given typeql write query
    """
    insert
      $john isa person, has name "John";
      $jane isa person, has name "Jane", has email "jane@doe.com";
      $alice isa person, has name "Alice", has age 33;
      $bob isa person, has name "Bob", has email "bob@ross.com", has age 22;
    """
    When get answers of typeql write query
    """
    match
      $p isa person;
      try { $p has email $email; };
      try { $p has age $age; };
    delete try { isset $email, $age;  has $email of $p; has $age of $p; };
    """
    Then uniquely identify answer concepts
      | p              | email                   | age         |
      | key:name:John  | none                    | none        |
      | key:name:Jane  | attr:email:jane@doe.com | none        |
      | key:name:Alice | none                    | attr:age:33 |
      | key:name:Bob   | attr:email:bob@ross.com | attr:age:22 |
    Then transaction commits
    Then connection open write transaction for database: typedb
    Then get answers of typeql read query
    """
    match $p isa person, has email $email;
    """
    Then uniquely identify answer concepts
      | p              | email                   |
      | key:name:Jane  | attr:email:jane@doe.com |
    Then get answers of typeql read query
    """
    match $p isa person, has age $age;
    """
    Then uniquely identify answer concepts
      | p              | age         |
      | key:name:Alice | attr:age:33 |


  Scenario: an optional relation is deleted
    Given typeql write query
    """
    insert
      $john isa person, has name "John";
      $jane isa person, has name "Jane";
      friendship (friend: $john, friend: $jane), has ref 0;
      $eve isa person, has name "Eve";
    """
    When get answers of typeql write query
    """
    match $p isa person, has name $name; try { $f isa friendship, links ($p); };
    delete try { isset $f; $f; };
    """
    Then uniquely identify answer concepts
      | p             | name           |
      | key:name:John | attr:name:John |
      | key:name:Jane | attr:name:Jane |
      | key:name:Eve  | attr:name:Eve  |
    Then transaction commits
    Then connection open write transaction for database: typedb
    Then get answers of typeql read query
    """
    match $p isa person; $f isa friendship, links ($p);
    """
    Then answer size is: 0


  Scenario: a links edge depending on an optional binding is deleted
    Given typeql write query
    """
    insert
      $john isa person, has name "John";
      $jane isa person, has name "Jane";
      friendship (friend: $john, friend: $jane), has ref 0;
      $eve isa person, has name "Eve";
    """
    When get answers of typeql write query
    """
    match $p isa person, has name $name; try { $f isa friendship, links ($p); };
    delete try { isset $f; links ($p) of $f; };
    """
    Then uniquely identify answer concepts
      | p             | name           | f         |
      | key:name:John | attr:name:John | key:ref:0 |
      | key:name:Jane | attr:name:Jane | key:ref:0 |
      | key:name:Eve  | attr:name:Eve  | none      |
    Then transaction commits
    Then connection open write transaction for database: typedb
    Then get answers of typeql read query
    """
    match $p isa person; $f isa friendship, links ($p);
    """
    Then answer size is: 0


  Scenario: In a delete stage, using an optional variable outside a try block errors.
    Then typeql write query; fails with a message containing: "The optional variable 'name' was used in a context where it may fail the branch if unset. Please acknowledge the optionality"
    """
    match
      $john isa person; try { $john has name $name; };
    delete
      has $name of $john;
    """


  Scenario: nested try blocks in delete are disallowed
    Given typeql write query; parsing fails
    """
    match $p isa person; try { $p has email $email, has age $age; };
    delete try { has $email of $p; try { has $age of $p; }; };
    """
