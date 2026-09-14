# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

#noinspection CucumberUndefinedStep
Feature: TypeQL Put Query

  Background: Open connection and create a simple extensible schema
    Given typedb starts
    Given connection opens with default authentication
    Given connection is open: true
    Given connection reset database: typedb
    Given connection open schema transaction for database: typedb
    Given typeql schema query
      """
      define

      entity person
        plays employment:employee,
        owns name @card(0..),
        owns age,
        owns email @unique @card(0..);

      entity company
        plays employment:employer,
        owns name;

      relation employment
        relates employee @card(0..),
        relates employer;

      attribute name
        value string;

      attribute age @independent,
        value integer;

      attribute email
        value string;
      """
    Given transaction commits

    Given set time-zone: Europe/London

  ####################
  #  Put Instances  #
  ###################

  Scenario: Putting an entity will create it if no entity exists, or return all matching entities
    Given connection open write transaction for database: typedb
    # Verify put does insert if not exists
    When get answers of typeql read query
    """
    match $x isa person;
    """
    Then answer size is: 0
    When get answers of typeql write query
      """
      put $x isa person;
      """
    Then answer size is: 1
    When get answers of typeql read query
    """
    match $x isa person;
    """
    Then answer size is: 1

    # Verify put does not insert if exists
    When get answers of typeql write query
      """
      put $x isa person;
      """
    Then answer size is: 1
    When get answers of typeql read query
    """
    match $x isa person;
    """
    Then answer size is: 1
    Then transaction commits

    Given connection open write transaction for database: typedb
    # Check the same behaviour post commit
    When get answers of typeql write query
      """
      put $x isa person;
      """
    Then answer size is: 1
    When get answers of typeql read query
    """
    match $x isa person;
    """
    Then answer size is: 1

    # Check put returns all matching answers by inserting one more person
    Given get answers of typeql write query
      """
      insert $x isa person;
      """
    When get answers of typeql write query
      """
      put $x isa person;
      """
    Then answer size is: 2


  Scenario: Putting an entity of a certain type will not create the entity if an entity of a subtype exists.
    Given connection open schema transaction for database: typedb
    When typeql schema query
      """
      define
      attribute ref value integer;
      person owns ref @key;
      entity child sub person;
      """
    Given transaction commits
    Given connection open write transaction for database: typedb
    Given typeql write query
      """
      insert $x isa child, has ref 0;
      """
    Given transaction commits

    Given connection open write transaction for database: typedb
    # Putting a person, does nothing since the child matches.
    When get answers of typeql read query
    """
    match $x isa! $t; $t sub person;
    """
    Then uniquely identify answer concepts
      | x         | t           |
      | key:ref:0 | label:child |

    When get answers of typeql write query
    """
    put $x isa person, has ref 0;
    """
    Then uniquely identify answer concepts
      | x         |
      | key:ref:0 |
    When get answers of typeql read query
    """
    match $x isa! $t; $t sub person;
    """
    Then uniquely identify answer concepts
      | x         | t           |
      | key:ref:0 | label:child |


  Scenario: putting just an entity with a key does not error if one exists with that key
    Given connection open schema transaction for database: typedb
    When typeql schema query
      """
      define
       attribute ref value integer;
       person owns ref @key;
      """
    Given transaction commits
    Given connection open write transaction for database: typedb
    When get answers of typeql write query
    """
    put $p isa person, has ref 0;
    """
    Then uniquely identify answer concepts
      | p         |
      | key:ref:0 |
    # Verify it exists
    When get answers of typeql read query
    """
    match $p isa person;
    """
    Then uniquely identify answer concepts
      | p         |
      | key:ref:0 |

    When get answers of typeql write query
    """
    put $p isa person, has ref 0;
    """
    Then uniquely identify answer concepts
      | p         |
      | key:ref:0 |
    Then transaction commits

    Given connection open write transaction for database: typedb
    # Verify the same after commit
    When get answers of typeql write query
    """
    put $p isa person, has ref 0;
    """
    Then uniquely identify answer concepts
      | p         |
      | key:ref:0 |


  ####################
  #  Put Ownerships  #
  ####################

  Scenario: Putting an entity, attribute and ownership will create them if no matching answer exists
    Given connection open write transaction for database: typedb
    # Verify nothing in the beginning
    When get answers of typeql read query
    """
    match
    $o isa! $t;
    { $t sub person; } or { $t sub age; };
    select $t;
    """
    Then answer size is: 0

    # Verify a put does insert each of them
    Given get answers of typeql write query
    """
    put $p isa person, has age 10;
    """
    Then answer size is: 1
    When get answers of typeql read query
    """
    match
    $o isa! $t;
    { $t sub person; } or { $t sub age; };
    select $t;
    """
    Then uniquely identify answer concepts
      | t            |
      | label:person |
      | label:age    |
    When get answers of typeql read query
    """
    match $p isa person, has age $age;
    """
    Then answer size is: 1
    Given transaction commits

    Given connection open write transaction for database: typedb
    # Inserting the same ownership does nothing
    Given get answers of typeql write query
    """
    put $p isa person, has age 10;
    """
    Then answer size is: 1
    When get answers of typeql read query
    """
    match $p isa person, has age $age;
    """
    Then answer size is: 1

    # A different age will insert though
    Given get answers of typeql write query
    """
    put $p isa person, has age 11;
    """
    Then answer size is: 1
    When get answers of typeql read query
    """
    match $p isa person, has age $age;
    """
    Then answer size is: 2


  Scenario: A match-put can be used to create an entity to own an existing attribute
    Given connection open schema transaction for database: typedb
    When typeql schema query
      """
      define
      attribute ref  @independent, value integer;
      person owns ref @key;
      """
    Given transaction commits
    Given connection open write transaction for database: typedb
    Given typeql write query
      """
      insert
        $r0 isa ref 0;
        $r1 isa ref 1;
      """
    Given transaction commits

    Given connection open write transaction for database: typedb
    When get answers of typeql read query
    """
    match $p isa person;
    """
    Then answer size is: 0
    When get answers of typeql write query
    """
    match $ref isa ref;
    put $p isa person, has $ref;
    """
    Then uniquely identify answer concepts
      | p         | ref        |
      | key:ref:0 | attr:ref:0 |
      | key:ref:1 | attr:ref:1 |
    When get answers of typeql read query
    """
    match $p isa person;
    """
    Then uniquely identify answer concepts
      | p         |
      | key:ref:0 |
      | key:ref:1 |


  Scenario: If the entire pattern does not match, put will insert the whole pattern. To insert a partial pattern, pipeline puts.
    Given connection open write transaction for database: typedb
    When typeql write query
    """
    insert $p1 isa person, has name "alice", has email "alice@email.com";
    insert $p2 isa person, has name "bob", has email "bob@email.com";
    """
    Given transaction commits

    Given connection open write transaction for database: typedb
    # Bad pattern with alice
    When get answers of typeql read query
    """
    match $p isa person, has name "alice";
    """
    Then answer size is: 1
    When typeql write query
    """
    put $p isa person, has name "alice", has email "alice@typedb.com";
    """
    When get answers of typeql read query
    """
    match $p isa person, has name "alice";
    """
    Then answer size is: 2
    When get answers of typeql read query
    """
    match $p isa person, has name "alice", has email $email;
    select $email;
    """
    Then uniquely identify answer concepts
      | email                       |
      | attr:email:alice@email.com  |
      | attr:email:alice@typedb.com |

    # Pipelined with bob
    When get answers of typeql read query
    """
    match $p isa person, has name "bob";
    """
    Then answer size is: 1
    When typeql write query
    """
    put $p isa person, has name "bob";
    put $p has email "bob@typedb.com";
    """
    When get answers of typeql read query
    """
    match $p isa person, has name "bob";
    """
    Then answer size is: 1
    When get answers of typeql read query
    """
    match $p isa person, has name "bob", has email $email;
    select $email;
    """
    Then uniquely identify answer concepts
      | email                     |
      | attr:email:bob@email.com  |
      | attr:email:bob@typedb.com |


  Scenario: Putting an ownership when a subtype already owns the attribute does nothing.
    Given connection open schema transaction for database: typedb
    When typeql schema query
      """
      define
      entity child sub person;
      """
    Given transaction commits

    Given connection open write transaction for database: typedb
    When typeql write query
    """
    insert
      $a isa child, has name "alice";
      $b isa person, has name "bob";
    """
    Given transaction commits

    Given connection open write transaction for database: typedb
    When get answers of typeql read query
    """ match $p isa person, has name "alice"; """
    Then answer size is: 1
    When get answers of typeql write query
    """ put $p isa person, has name "alice"; """
    Then answer size is: 1
    When get answers of typeql read query
    """ match $p isa person, has name "alice"; """
    Then answer size is: 1

    # bob was inserted as a person, put-ting a child bob creates a new entity & ownership.
    When get answers of typeql read query
    """ match $p isa person, has name "bob"; """
    Then answer size is: 1
    When get answers of typeql write query
    """ put $p isa child, has name "bob"; """
    Then answer size is: 1
    When get answers of typeql read query
    """ match $p isa person, has name "bob"; """
    Then answer size is: 2


  Scenario: Putting an ownership when a subtype is already owned does nothing.
    Given connection open schema transaction for database: typedb
    When typeql schema query
      """
      define
      attribute first-name sub name;
      person owns first-name;
      """
    Given transaction commits

    Given connection open write transaction for database: typedb
    When typeql write query
    """
    insert
      $a isa person, has first-name "alice";
      $b isa person, has name "bob";
    """
    Given transaction commits

    Given connection open write transaction for database: typedb
    When get answers of typeql read query
    """ match $p isa person, has name "alice"; """
    Then answer size is: 1
    When get answers of typeql write query
    """ put $p isa person, has name "alice"; """
    Then answer size is: 1
    When get answers of typeql read query
    """ match $p isa person, has name "alice"; """
    Then answer size is: 1

    # bob owns name. 'put' with a first-name "Bob" creates a new entity & ownership.
    When get answers of typeql read query
    """ match $p isa person, has name "bob"; """
    Then answer size is: 1
    When get answers of typeql write query
    """ put $p isa person, has first-name "bob"; """
    Then answer size is: 1
    When get answers of typeql read query
    """ match $p isa person, has name "bob"; """
    Then answer size is: 2


  Scenario: Trying to put an ownership of an abstract attribute fails even if an ownership of a concrete-subtype is available.
    Given connection open schema transaction for database: typedb
    When typeql schema query
      """
      define
      name @abstract;
      attribute address @abstract, value string;
      attribute residential-address sub address;
      person owns residential-address;
      """
    Given transaction commits

    Given connection open write transaction for database: typedb
    When typeql write query
    """
    insert $p isa person, has residential-address "9, Downing Street";
    """
    Given transaction commits

    Given connection open write transaction for database: typedb
    When get answers of typeql read query
    """
      match $p isa person, has residential-address "9, Downing Street";
    """
    Then answer size is: 1
    When typeql write query; fails with a message containing: "Type-inference was unable to find compatible types for the pair of variables"
    """
      put $p isa person, has address "9, Downing Street";
    """


  ####################
  #  Put relations   #
  ####################

  Scenario: Put can be used to create entites & relations between them
    Given connection open write transaction for database: typedb
    When get answers of typeql read query
    """
    match
      $emp isa employment, links (employer: $company, employee: $person);
      $company has name $cname;
      $person has name $pname;
    """
    Then answer size is: 0

    When get answers of typeql write query
    """
    put
      $emp isa employment, links (employer: $company, employee: $person);
      $company isa company, has name "typedb";
      $person isa person, has name "alice";
    """
    Then answer size is: 1
    When get answers of typeql read query
    """
    match
      $emp isa employment, links (employer: $company, employee: $person);
      $company isa company, has name $cname;
      $person isa person, has name $pname;
    select $cname, $pname;
    """
    Then uniquely identify answer concepts
      | cname            | pname           |
      | attr:name:typedb | attr:name:alice |


  Scenario: A match-put can be used to match entities and insert a relation between them only if it does not exist.
    Given connection open write transaction for database: typedb
    Given typeql write query
    """
    insert
      $c isa company, has name "typedb";
      $a isa person, has name "alice";
      $b isa person, has name "bob";
    """
    Given transaction commits

    Given connection open write transaction for database: typedb
    When get answers of typeql read query
    """
    match
      $emp isa employment, links (employer: $company, employee: $person);
      $company has name $cname;
      $person has name $pname;
    """
    Then answer size is: 0
    When get answers of typeql write query
    """
    match
      $company isa company, has name "typedb";
      $person isa person, has name "alice";
    put
      $emp isa employment, links (employer: $company, employee: $person);
    """
    Then answer size is: 1
    When get answers of typeql read query
    """
    match
      $emp isa employment, links (employer: $company, employee: $person);
      $company has name $cname;
      $person has name $pname;
    select $cname, $pname;
    """
    Then answer size is: 1
    Then uniquely identify answer concepts
      | cname            | pname           |
      | attr:name:typedb | attr:name:alice |

    # Doing it again does not increase the answer count.
    When get answers of typeql write query
    """
    match
      $company isa company, has name "typedb";
      $person isa person, has name "alice";
    put
      $emp isa employment, links (employer: $company, employee: $person);
    """
    Then answer size is: 1
    When get answers of typeql read query
    """
    match
      $emp isa employment, links (employer: $company, employee: $person);
      $company has name $cname;
      $person has name $pname;
    select $cname, $pname;
    """
    Then answer size is: 1
    Then uniquely identify answer concepts
      | cname            | pname           |
      | attr:name:typedb | attr:name:alice |


  ####################
  #  Validation      #
  ####################

  Scenario: Concepts in a put stage must either be an input or be insertable in the put stage.
    Given connection open write transaction for database: typedb
    Then typeql write query; fails with a message containing: "Ensure the variable is available from a previous stage or is inserted in this stage"
    """
    put $p has age 10;
    """
    Then transaction is open: false

  Scenario: Put stages may only contain thing statements
    Given connection open write transaction for database: typedb
    Then typeql write query; fails
    """
    put person owns name;
    """

    Given connection open write transaction for database: typedb
    Then typeql write query; fails
    """
    put
      let $age = 10;
      $p isa person, has age $age;
    """

    Given connection open write transaction for database: typedb
    Then typeql write query; fails with a message containing: "Illegal statement 'expression' provided for a put stage. Only 'has', 'links' and 'isa' constraints are allowed."
    """
    put $p isa person, has age (10 + 5);
    """


#############
# OPTIONALS #
#############


  Scenario: a has edge depending on an optional binding can be inserted
    Given connection open schema transaction for database: typedb
    When typeql schema query
      """
      define
      attribute ref value integer;
      relation friendship,
        relates friend @card(0..),
        owns ref @key;
      person
        plays friendship:friend,
        owns ref @key;
      entity also-person
        plays friendship:friend,
        owns age,
        owns ref @key;
      """
    Given transaction commits
    Given connection open write transaction for database: typedb
    Given typeql write query
    """
    insert
      $john isa person, has name "John", has ref 0;
      $jane isa person, has name "Jane", has ref 1, has age 33;
      friendship (friend: $john, friend: $jane), has ref 0;
    """
    When get answers of typeql write query
    """
    match
      $p isa person, has ref $ref; try { $p has age $age; };
    put $q isa also-person, has $ref; if { isset $age; } { $q has $age; };
    """
    Then uniquely identify answer concepts
      | p         | q         | age         |
      | key:ref:0 | key:ref:0 | none        |
      | key:ref:1 | key:ref:1 | attr:age:33 |
    Then transaction commits
    Then connection open write transaction for database: typedb
    Then get answers of typeql read query
    """
    match $p isa person, has age $age;
    """
    Then answer size is: 1


  Scenario: a relation linking an optional player is inserted
    Given connection open schema transaction for database: typedb
    When typeql schema query
      """
      define
      attribute ref value integer;
      relation friendship,
        relates friend @card(0..),
        owns ref @key;
      person
        plays friendship:friend,
        owns ref @key;
      """
    Given transaction commits

    Given connection open write transaction for database: typedb
    Given typeql write query
    """
    insert
      $john isa person, has name "John", has ref 0;
      $jane isa person, has name "Jane", has ref 1, has email "jane@doe.com";
    """
    When get answers of typeql write query
    """
    match
      $p isa person;
      try { $q isa person, has email $_; not { $q is $p; }; };
    put
      if { isset $q; } { $f isa friendship, links (friend: $p, friend: $q), has ref 0; };
    """
    Then uniquely identify answer concepts
      | p         | q         | f    |
      | key:ref:0 | key:ref:1 | none |
      | key:ref:1 | none      | none |
    When get answers of typeql write query
    """
    match
      $p isa person, has ref $ref;
      try { $q isa person, has email $_; not { $q is $p; }; };
    put
      $f isa friendship, links(friend: $p), has $ref;
      if { isset $q; } { $f links (friend: $q); };
    """
    Then uniquely identify answer concepts
      | p         | q         | f         |
      | key:ref:0 | key:ref:1 | key:ref:0 |
      | key:ref:1 | none      | key:ref:1 |
    Then transaction commits

    Then connection open read transaction for database: typedb
    Then get answers of typeql read query
    """
    match $f isa friendship;
    """
    Then answer size is: 2


  Scenario: In a put stage, using an optional variable outside an if block errors.
    Given connection open write transaction for database: typedb
    Then typeql write query; fails with a message containing: "The optional variable 'age' was used in a context where it may fail the branch if unset. Please acknowledge the optionality"
    """
    match
      $p isa person;
      try { $p has age $age; };
    put
      $q isa person, has name "Jane", has $age;
    """


  Scenario: nested if blocks in put are disallowed
    Given connection open write transaction for database: typedb
    Given typeql write query; fails
    """
    match
      $p isa person;
      try { $p has name $name, has age $age; };
    put
      $q isa person;
      if { isset $name; } {
         $q has $name;
         if { isset $name, $age; } {
            $q has $age;
         };
      };
    """
