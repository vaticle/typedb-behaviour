# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

#noinspection CucumberUndefinedStep
Feature: TypeQL Update Query

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
        plays parentship:parent,
        plays parentship:child,
        owns name,
        owns age,
        owns ref @key,
        owns email @unique @card(0..);
      relation friendship,
        relates friend,
        owns ref @key;
      relation parentship,
        relates parent,
        relates child,
        owns ref;
      attribute name value string;
      attribute ref @independent, value integer;
      attribute age @independent, value integer;
      attribute email value string;
      """
    Given transaction commits
    Given connection open write transaction for database: typedb

  #######################
  # UNSUPPORTED UPDATES #
  #######################

  Scenario: Update queries cannot define or update schema
    Given transaction closes

    Given connection open schema transaction for database: typedb
    Then typeql write query; fails
      """
      match
        $p label person;
      update
        $p label superperson;
      """
    Given connection open schema transaction for database: typedb

    Then typeql write query; fails
      """
      match
        $p label person;
      update
        entity superperson;
      """
    Given connection open schema transaction for database: typedb

    Then typeql write query; fails
      """
      match
        $p label person;
      update
        $p owns name;
      """
    Given connection open schema transaction for database: typedb

    Then typeql write query; parsing fails
      """
      match
        $p label person;
      update
        $p @abstract;
      """

    Then typeql write query; fails
      """
      match
        $p label person;
      update
        $p owns name @card(5..);
      """
    Given connection open schema transaction for database: typedb

    Then typeql write query; fails
      """
      match
        $n label name;
      update
        $n value datetime;
      """
    Given connection open schema transaction for database: typedb

    Then typeql write query; fails
      """
      update
        entity superperson;
      """


  Scenario: Update queries cannot declare new instances through isa
    Given typeql write query
      """
      insert
        $p isa person, has ref 0, has name "Bob";
      """
    Given transaction commits

    Given connection open write transaction for database: typedb
    Then typeql write query; fails with a message containing: "variable 'a' referenced in the update stage is unavailable"
      """
      update
        $a isa name "John";
      """

    When connection open write transaction for database: typedb
    Then typeql write query; fails with a message containing: "variable 'a' referenced in the update stage is unavailable"
      """
      match
        $p isa person;
      update
        $a isa name "John";
      """

    When connection open write transaction for database: typedb
    Then typeql write query; fails with a message containing: "Illegal statement provided for an update stage"
      """
      match
        $p isa person, has name $a;
      update
        $a isa name "Bob";
      """

    When connection open write transaction for database: typedb
    Then typeql write query; fails with a message containing: "Illegal statement provided for an update stage"
      """
      match
        $p isa person, has name $a;
      update
        $a isa name "John";
      """

    When connection open write transaction for database: typedb
    Then typeql write query; fails with a message containing: "variable 'p' referenced in the update stage is unavailable"
      """
      update
        $p isa person;
      """

    When connection open write transaction for database: typedb
    Then typeql write query; fails with a message containing: "variable 'p' referenced in the update stage is unavailable"
      """
      update
        $p isa parentship;
      """

    When connection open write transaction for database: typedb
    Then typeql write query; fails with a message containing: "Illegal statement provided for an update stage"
      """
      match $p isa person;
      update
        (parent: $p) isa parentship;
      """


  Scenario: Update queries cannot match instances and types or illegally update them
    Given typeql write query
      """
      insert
        $p isa person, has ref 0, has name "Bob";
      """
    Given transaction commits

    Given connection open write transaction for database: typedb
    Then typeql write query; fails with a message containing: "variable 'p' referenced in the update stage is unavailable"
      """
      update
        $p iid 0x1e00000000001234567890;
      """

    When connection open write transaction for database: typedb
    Then typeql write query; fails with a message containing: "variable 'p' referenced in the update stage is unavailable"
      """
      update
        $p isa person;
      """

    When connection open write transaction for database: typedb
    Then typeql write query; parsing fails
      """
      update > 5;
      """

    Then typeql write query; parsing fails
      """
      update = 5;
      """

    Then typeql write query; fails
      """
      update 6 > 5;
      """
    When connection open write transaction for database: typedb

    Then typeql write query; fails
      """
      update $p is $f;
      """
    When connection open write transaction for database: typedb

    Then typeql write query; fails
      """
      update person owns name;
      """

  #############################
  # HAS (ATTRIBUTE OWNERSHIP) #
  #############################

  Scenario: Has update on an empty match does nothing
    When get answers of typeql write query
      """
      match
        $p isa person;
      update
        $p has name "Bob";
      """
    Then answer size is: 0

  Scenario: Has can be updated by a new attribute without a variable
    Given typeql write query
      """
      insert $p isa person, has ref 0;
      """

    When get answers of typeql write query
      """
      match
        $p isa person;
      update
        $p has name "Alice";
      """
    Then uniquely identify answer concepts
      | p              |
      | key:name:Alice |
    When get answers of typeql read query
      """
      match $p isa person, has name $n;
      """
    Then uniquely identify answer concepts
      | p         | n               |
      | key:ref:0 | attr:name:Alice |

    When get answers of typeql write query
      """
      match
        $p isa person;
      update
        $p has name "Bob";
      """
    Then uniquely identify answer concepts
      | p         |
      | key:ref:0 |
    When get answers of typeql read query
      """
      match $p isa person, has name $n;
      """
    Then uniquely identify answer concepts
      | p         | n             |
      | key:ref:0 | attr:name:Bob |

    When get answers of typeql write query
      """
      match
        $p isa person, has name "Bob";
      update
        $p has name "Charlie";
      """
    Then uniquely identify answer concepts
      | p         |
      | key:ref:0 |
    When get answers of typeql read query
      """
      match $p isa person, has name $n;
      """
    Then uniquely identify answer concepts
      | p         | n                 |
      | key:ref:0 | attr:name:Charlie |

    When get answers of typeql write query
      """
      match
        $p isa person, has name $_;
      update
        $p has name "Donald";
      """
    Then uniquely identify answer concepts
      | p         |
      | key:ref:0 |
    When get answers of typeql read query
      """
      match $p isa person, has name $n;
      """
    Then uniquely identify answer concepts
      | p         | n                |
      | key:ref:0 | attr:name:Donald |


  Scenario: Has can be updated with an attribute variable
    Given transaction closes
    Given connection open schema transaction for database: typedb
    Given typeql schema query
      """
      define name @independent;
      """
    Given typeql write query
      """
      insert
        $p isa person, has ref 0;
        $n isa name "Charlie";
      """
    Given transaction commits
    Given connection open write transaction for database: typedb

    When get answers of typeql write query
      """
      insert
        $n isa name "Alice";
      match
        $p isa person;
      update
        $p has $n;
      """
    Then uniquely identify answer concepts
      | p              | n               |
      | key:name:Alice | attr:name:Alice |
    When get answers of typeql read query
      """
      match $p isa person, has name $n;
      """
    Then uniquely identify answer concepts
      | p         | n               |
      | key:ref:0 | attr:name:Alice |

    When get answers of typeql write query
      """
      match
        $p isa person;
        let $n = "Bob";
      update
        $p has name == $n;
      """
    Then uniquely identify answer concepts
      | p         | n                |
      | key:ref:0 | value:string:Bob |
    When get answers of typeql read query
      """
      match $p isa person, has name $n;
      """
    Then uniquely identify answer concepts
      | p         | n             |
      | key:ref:0 | attr:name:Bob |

    When get answers of typeql write query
      """
      match
        $p isa person;
        $n isa name "Charlie";
      update
        $p has $n;
      """
    Then uniquely identify answer concepts
      | n                 | p         |
      | attr:name:Charlie | key:ref:0 |
    When get answers of typeql read query
      """
      match $p isa person, has name $n;
      """
    Then uniquely identify answer concepts
      | p         | n                 |
      | key:ref:0 | attr:name:Charlie |

    Then typeql write query; fails with a message containing: "Illegal 'isa' provided for variable 'n' that is input from a previous stage"
      """
      match
        $p isa person;
        $n isa name "Alice";
      update
        $p has name $n;
      """

    When connection open write transaction for database: typedb
    Then typeql write query; fails with a message containing: "The variable 'n' referenced in the update stage is unavailable"
      """
      match
        $p isa person;
      update
        $n isa name "Charlie";
        $p has $n;
      """

    When connection open write transaction for database: typedb
    Then typeql write query; fails
      """
      match
        $p isa person;
      update
        let $n = "Charlie";
        $p has name == $n;
      """


  Scenario: Has can be updated by an arithmetic operation, but not a comparison
    Given transaction closes
    Given connection open schema transaction for database: typedb
    Given typeql schema query
      """
      define person owns balance; attribute balance value decimal;
      """
    Given typeql write query
      """
      insert
        $p0 isa person, has ref 0, has balance 20.0dec;
        $p1 isa person, has ref 1, has balance 0.0dec;
      """
    Given transaction commits
    Given connection open write transaction for database: typedb

    # TODO: Uncomment when inserts can do this. Now it returns errors! Write tests for inserts + cover it here
#    When get answers of typeql write query
#      """
#      match
#        $p isa person, has balance $b;
#      update
#        $p has balance $b + 15;
#      """
#    Then uniquely identify answer concepts
#      | p         | b                    |
#      | key:ref:0 | attr:balance:20.0dec |
#      | key:ref:1 | attr:balance:0.0dec  |
#    When get answers of typeql read query
#      """
#      match $p isa person, has balance $b;
#      """
#    Then uniquely identify answer concepts
#      | p         | b                    |
#      | key:ref:0 | attr:balance:35.0dec |
#      | key:ref:1 | attr:balance:15.0dec |
#
#    When get answers of typeql write query
#      """
#      match
#        $p isa person, has balance $_;
#        let $v = 15.5dec;
#      update
#        $p has $v + 15;
#      """
#    Then uniquely identify answer concepts
#      | p         | v                     |
#      | key:ref:0 | value:decimal:15.5dec |
#      | key:ref:1 | value:decimal:15.5dec |
#    When get answers of typeql read query
#      """
#      match $p isa person, has balance $b;
#      """
#    Then uniquely identify answer concepts
#      | p         | b                    |
#      | key:ref:0 | attr:balance:30.5dec |
#      | key:ref:1 | attr:balance:30.5dec |

    When typeql write query; fails with a message containing: "'b' cannot be declared as both a 'ThingType' and as a 'Attribute'"
      """
      match
        $p isa person, has balance $b;
      update
        $p has $b + 15;
      """

    When connection open write transaction for database: typedb
    Then typeql write query; fails with a message containing: "'b' cannot be declared as both a 'ThingType' and as a 'Attribute'"
      """
      match
        $p isa person, has balance $b;
      update
        $p has $b < 15;
      """

    When connection open write transaction for database: typedb
    Then typeql write query; parsing fails
      """
      match
        $p isa person, has balance $b;
      update
        $p has balance $b < 15;
      """


  Scenario: Can update has from any other write stage, even right after creating a new instance
    When get answers of typeql write query
      """
      insert
        $p isa person, has ref 0, has name "Alice";
      update
        $p has name "Bob";
      update
        $p has name "Charlie";
      update
        $p has name "David";
      """
    When get answers of typeql read query
      """
      match $p isa person, has name $n;
      """
    Then uniquely identify answer concepts
      | p         | n               |
      | key:ref:0 | attr:name:David |


  Scenario: Cannot declare new attribute and value variables in an update stage
    Then typeql write query; fails
      """
      insert
        $p isa person, has ref 0, has name "Alice";
      update
        let $n = "Bob";
        $p has name $n;
      """

    When connection open write transaction for database: typedb
    Then typeql write query; fails
      """
      insert
        $p isa person, has ref 0, has name "Alice";
      update
        let $n = "Bob";
        $p has name == $n;
      """

    When connection open write transaction for database: typedb
    Then typeql write query; fails with a message containing: "variable 'n' referenced in the update stage is unavailable"
      """
      insert
        $p isa person, has ref 0, has name "Alice";
      update
        $n isa name "Bob";
        $p has $n;
      """


    # TODO: Uncomment after implemented [REP254] The language feature is not yet implemented: BuiltinFunction("max")
#  Scenario: Has can be updated by a built-in function call
#    Given transaction closes
#    Given connection open schema transaction for database: typedb
#    Given typeql schema query
#      """
#      define
#        person owns balance;
#        attribute balance value decimal;
#      """
#    Given typeql write query
#      """
#      insert
#        $p0 isa person, has ref 0, has balance 20.0dec;
#        $p1 isa person, has ref 1, has balance 0.0dec;
#      """
#    Given transaction commits
#    Given connection open write transaction for database: typedb
#
#    When get answers of typeql write query
#      """
#      match
#        $p isa person, has balance $b;
#      update
#        $p has balance max($b);
#      """
#    Then uniquely identify answer concepts
#      | p         | b                    |
#      | key:ref:0 | attr:balance:20.0dec |
#      | key:ref:1 | attr:balance:0.0dec  |
#    When get answers of typeql read query
#      """
#      match $p isa person, has balance $b;
#      """
#    Then uniquely identify answer concepts
#      | p         | b                    |
#      | key:ref:0 | attr:balance:20.0dec |
#      | key:ref:1 | attr:balance:20.0dec |


  # TODO: Uncomment and adjust when user-defined functions can be called
#  Scenario: Has can be updated by a user-defined function call
#    Given transaction closes
#    Given connection open schema transaction for database: typedb
#    Given typeql schema query
#      """
#      define
#        person owns balance; attribute balance value decimal;
#        fun increased_balance($b: balance) -> decimal:
#          match
#            let $ib = $b + 15.0dec;
#          return first $ib;
#        fun get_balance($p: person) -> balance:
#          match
#            $p has balance $b;
#          return first $b;
#      """
#    Given typeql write query
#      """
#      insert
#        $p0 isa person, has ref 0, has balance 20.0dec;
#        $p1 isa person, has ref 1, has balance 0.0dec;
#      """
#    Given transaction commits
#    Given connection open write transaction for database: typedb
#
#    When get answers of typeql write query
#      """
#      match
#        $p isa person, has balance $b;
#      update
#        $p has balance increased_balance($b);
#      """
#    Then uniquely identify answer concepts
#      | p         | b                    |
#      | key:ref:0 | attr:balance:20.0dec |
#      | key:ref:1 | attr:balance:0.0dec  |
#    When get answers of typeql read query
#      """
#      match $p isa person, has balance $b;
#      """
#    Then uniquely identify answer concepts
#      | p         | b                    |
#      | key:ref:0 | attr:balance:30.5dec |
#      | key:ref:1 | attr:balance:30.5dec |
#
#    When transaction commits
#    When connection open write transaction for database: typedb
#    When get answers of typeql read query
#      """
#      match $p isa person, has balance $b;
#      """
#    Then uniquely identify answer concepts
#      | p         | b                    |
#      | key:ref:0 | attr:balance:30.5dec |
#      | key:ref:1 | attr:balance:30.5dec |
#
#    Then typeql write query; fails with a message containing: "todo"
#      """
#      match
#        $p isa person, has balance $b;
#      update
#        $p has increased_balance($b);
#      """
#    When transaction closes
#
#    When connection open write transaction for database: typedb
#    Then typeql write query; fails with a message containing: "todo"
#      """
#      match
#        $p isa person, has balance $b;
#      update
#        let $ib = increased_balance($b);
#        $p has balance $ib;
#      """
#
#    When connection open write transaction for database: typedb
#    When get answers of typeql write query
#      """
#      match
#        $p isa person, has ref 0, has balance $b;
#        let $nb = increased_balance($b);
#      update
#        $p has balance $nb;
#      """
#    Then uniquely identify answer concepts
#      | p         | b                    | nb                    |
#      | key:ref:0 | attr:balance:30.5dec | value:decimal:46.0dec |
#    When get answers of typeql read query
#      """
#      match $p isa person, has balance $b;
#      """
#    Then uniquely identify answer concepts
#      | p         | b                    |
#      | key:ref:0 | attr:balance:46.0dec |
#      | key:ref:1 | attr:balance:30.5dec |
#    When transaction commits
#
#    When connection open write transaction for database: typedb
#    When get answers of typeql write query
#      """
#      match
#        $p0 isa person, has ref 0, has balance $b0;
#        $p1 isa person, has ref 1, has balance $b1;
#      update
#        $p1 has get_balance($p0);
#      """
#    Then uniquely identify answer concepts
#      | p0        | p1        | b0                   | b1                    |
#      | key:ref:0 | key:ref:1 | attr:balance:46.0dec | value:decimal:30.5dec |
#    When get answers of typeql read query
#      """
#      match $p isa person, has balance $b;
#      """
#    Then uniquely identify answer concepts
#      | p         | b                    |
#      | key:ref:0 | attr:balance:46.0dec |
#      | key:ref:1 | attr:balance:46.0dec |
#
#    Then typeql write query; fails with a message containing: "todo"
#      """
#      match
#        $p0 isa person, has ref 0, has balance $b0;
#        $p1 isa person, has ref 1, has balance $b1;
#      update
#        $p1 has balance get_balance($p0);
#      """


  Scenario Outline: Cannot update has with cardinality higher than 1: @card(<card>)
    Given transaction closes
    Given connection open schema transaction for database: typedb
    Given typeql schema query
      """
      define person owns name @card(<card>);
      """
    Given typeql write query
      """
      insert $p isa person, has ref 0, <has>;
      """
    Given transaction commits

    When connection open write transaction for database: typedb
    Then typeql write query; fails with a message containing: "cardinality should not exceed 1"
      """
      match
        $p isa person;
      update
        $p <has-changed>;
      """
    Examples:
      | card  | has                                 | has-changed                       |
      | 0..   | has name "Alice"                    | has name "Bob"                    |
      | 0..10 | has name "Alice"                    | has name "Bob"                    |
      | 0..2  | has name "Alice"                    | has name "Bob"                    |
      | 0..2  | has name "Alice", has name "Morgan" | has name "Bob"                    |
      | 1..   | has name "Alice"                    | has name "Bob"                    |
      | 1..2  | has name "Alice"                    | has name "Bob"                    |
      | 1..2  | has name "Alice"                    | has name "Bob", has name "Marley" |
      | 2..2  | has name "Alice", has name "Morgan" | has name "Bob", has name "Marley" |
      | 2     | has name "Alice", has name "Morgan" | has name "Bob", has name "Marley" |
      | 2..   | has name "Alice", has name "Morgan" | has name "Bob", has name "Marley" |


  Scenario: Can update has with a correct declared cardinality even if a supertype has a @card(1..)
    Given transaction closes
    Given connection open schema transaction for database: typedb
    Given typeql schema query
      """
      define
        person owns name @card(0..), owns first-name @card(0..1), owns surname @card(1..1);
        attribute first-name sub name;
        attribute surname sub name;
      """
    Given typeql write query
      """
      insert $p isa person, has ref 0, has surname "Morgan";
      """
    Given transaction commits

    When connection open write transaction for database: typedb
    When get answers of typeql read query
      """
      match $p isa person, has name $n;
      """
    Then uniquely identify answer concepts
      | p         | n                   |
      | key:ref:0 | attr:surname:Morgan |

    When typeql write query
      """
      match
        $p isa person, has ref 0;
      update
        $p has first-name "Alice";
      """
    When get answers of typeql read query
      """
      match $p isa person, has name $n;
      """
    Then uniquely identify answer concepts
      | p         | n                     |
      | key:ref:0 | attr:first-name:Alice |
      | key:ref:0 | attr:surname:Morgan   |

    When typeql write query
      """
      match
        $p isa person, has ref 0;
      update
        $p has surname "Cooper";
      """
    When get answers of typeql read query
      """
      match $p isa person, has name $n;
      """
    Then uniquely identify answer concepts
      | p         | n                     |
      | key:ref:0 | attr:first-name:Alice |
      | key:ref:0 | attr:surname:Cooper   |

    Then typeql write query; fails with a message containing: "cardinality should not exceed 1"
      """
      match
        $p isa person, has ref 0;
      update
        $p has name "Alice Cooper";
      """


  Scenario: Has for keys can be updated
    Given typeql write query
      """
      insert $p isa person, has ref 0;
      """

    When get answers of typeql write query
      """
      match
        $p isa person;
      update
        $p has ref 1;
      """
    Then uniquely identify answer concepts
      | p         |
      | key:ref:1 |
    When get answers of typeql read query
      """
      match $p isa person, has ref $r;
      """
    Then uniquely identify answer concepts
      | p         | r          |
      | key:ref:1 | attr:ref:1 |

    When get answers of typeql write query
      """
      match
        $p isa person, has ref 1;
      update
        $p has ref 0;
      """
    Then uniquely identify answer concepts
      | p         |
      | key:ref:0 |
    When get answers of typeql read query
      """
      match $p isa person, has ref $r;
      """
    Then uniquely identify answer concepts
      | p         | r          |
      | key:ref:0 | attr:ref:0 |

    When get answers of typeql write query
      """
      match
        $p isa person, has ref $_;
      update
        $p has ref 5;
      """
    Then uniquely identify answer concepts
      | p         |
      | key:ref:5 |
    When get answers of typeql read query
      """
      match $p isa person, has ref $r;
      """
    Then uniquely identify answer concepts
      | p         | r          |
      | key:ref:5 | attr:ref:5 |


  Scenario: Update cannot result in keys conflict
    Given typeql write query
      """
      insert $p0 isa person, has ref 0;
      insert $p1 isa person, has ref 1;
      """
    Given transaction commits

    When connection open write transaction for database: typedb
    Then typeql write query; fails with a message containing: "Constraint '@unique' has been violated"
      """
      match
        $p isa person;
      update
        $p has ref 2;
      """

    When connection open write transaction for database: typedb
    When get answers of typeql write query
      """
      match
        $p isa person, has ref 0;
      update
        $p has ref 2;
      """
    Then uniquely identify answer concepts
      | p         |
      | key:ref:2 |
    When get answers of typeql read query
      """
      match $p isa person, has ref $r;
      """
    Then uniquely identify answer concepts
      | p         | r          |
      | key:ref:2 | attr:ref:2 |
      | key:ref:1 | attr:ref:1 |


  Scenario: Has update can result in 0 changes if it updates existing data by the same value
    Given typeql write query
      """
      insert $p isa person, has ref 0, has name "Alice";
      """
    Given get answers of typeql read query
      """
      match $p isa person, has name $n;
      """
    Given uniquely identify answer concepts
      | p         | n               |
      | key:ref:0 | attr:name:Alice |

    When get answers of typeql write query
      """
      match
        $p isa person;
      update
        $p has name "Alice";
      """
    Then uniquely identify answer concepts
      | p         |
      | key:ref:0 |
    When get answers of typeql read query
      """
      match $p isa person, has name $n;
      """
    Then uniquely identify answer concepts
      | p         | n               |
      | key:ref:0 | attr:name:Alice |


  Scenario: Has for attribute subtypes can be updated without affecting sub and supertypes
    Given transaction closes
    Given connection open schema transaction for database: typedb
    Given typeql schema query
      """
      define
        person owns first-name, owns surname, owns old-surname;
        attribute first-name sub name;
        attribute surname sub name;
        attribute old-surname sub surname;
      """
    Given transaction commits

    Given connection open write transaction for database: typedb
    Given typeql write query
      """
      insert $p isa person, has ref 0,
        has name "Alice Morgan",
        has first-name "Alice",
        has surname "Morgan";
      """
    Given get answers of typeql read query
      """
      match $p isa person, has name $n;
      """
    Given uniquely identify answer concepts
      | p         | n                        |
      | key:ref:0 | attr:name:"Alice Morgan" |
      | key:ref:0 | attr:first-name:"Alice"  |
      | key:ref:0 | attr:surname:"Morgan"    |

    When get answers of typeql write query
      """
      match
        $p isa person;
      update
        $p has name "Bob Marley";
      """
    Then uniquely identify answer concepts
      | p         |
      | key:ref:0 |
    When get answers of typeql read query
      """
      match $p isa person, has name $n;
      """
    Then uniquely identify answer concepts
      | p         | n                       |
      | key:ref:0 | attr:name:"Bob Marley"  |
      | key:ref:0 | attr:first-name:"Alice" |
      | key:ref:0 | attr:surname:"Morgan"   |

    When get answers of typeql write query
      """
      match
        $p isa person;
      update
        $p has first-name "Bob";
      """
    Then uniquely identify answer concepts
      | p         |
      | key:ref:0 |
    When get answers of typeql read query
      """
      match $p isa person, has name $n;
      """
    Then uniquely identify answer concepts
      | p         | n                      |
      | key:ref:0 | attr:name:"Bob Marley" |
      | key:ref:0 | attr:first-name:"Bob"  |
      | key:ref:0 | attr:surname:"Morgan"  |

    When get answers of typeql write query
      """
      match
        $p isa person;
      update
        $p has surname "Marley";
      """
    Then uniquely identify answer concepts
      | p         |
      | key:ref:0 |
    When get answers of typeql read query
      """
      match $p isa person, has name $n;
      """
    Then uniquely identify answer concepts
      | p         | n                      |
      | key:ref:0 | attr:name:"Bob Marley" |
      | key:ref:0 | attr:first-name:"Bob"  |
      | key:ref:0 | attr:surname:"Marley"  |

    When get answers of typeql write query
      """
      match
        $p isa person, has surname $sn;
      delete
        has $sn of $p;
      update
        $p has old-surname "Morgan";
      """
    Then uniquely identify answer concepts
      | sn                  | p         |
      | attr:surname:Marley | key:ref:0 |
    When get answers of typeql read query
      """
      match $p isa person, has name $n;
      """
    Then uniquely identify answer concepts
      | p         | n                         |
      | key:ref:0 | attr:name:"Bob Marley"    |
      | key:ref:0 | attr:first-name:"Bob"     |
      | key:ref:0 | attr:old-surname:"Morgan" |

    When get answers of typeql write query
      """
      insert
        $n isa surname "Cruise";
      match
        $p isa person;
      update
        $p has $n;
      """
    Then uniquely identify answer concepts
      | p         | n                     |
      | key:ref:0 | attr:surname:"Cruise" |
    When get answers of typeql read query
      """
      match $p isa person, has name $n;
      """
    Then uniquely identify answer concepts
      | p         | n                         |
      | key:ref:0 | attr:name:"Bob Marley"    |
      | key:ref:0 | attr:first-name:"Bob"     |
      | key:ref:0 | attr:surname:"Cruise"     |
      | key:ref:0 | attr:old-surname:"Morgan" |
    Then transaction commits; fails with a message containing: "card"


  Scenario: Update queries can only use bound variables with 'has'
    Then typeql write query; fails with a message containing: "variable 'p' referenced in the update stage is unavailable"
      """
      update
        $p has name "Bob";
      """

    When connection open write transaction for database: typedb
    When get answers of typeql write query
      """
      insert
        $p isa person, has ref 0, has name "Alice";
      update
        $p has name "Bob";
      """
    Then uniquely identify answer concepts
      | p         |
      | key:ref:0 |
    When get answers of typeql read query
      """
      match $p isa person, has name $n;
      """
    Then uniquely identify answer concepts
      | p         | n             |
      | key:ref:0 | attr:name:Bob |


  Scenario: Update queries are validated similarly to insert queries and do not allow creating abstract has instances
    Given transaction closes
    Given connection open schema transaction for database: typedb
    Given typeql schema query
      """
      define
        name @abstract;
      """
    Given transaction commits

    When connection open write transaction for database: typedb
    Then typeql write query; fails with a message containing: "Type-inference was unable to find compatible types for the pair of variables"
      """
      insert
        $p isa person, has ref 0;
      update
        $p has name "Bob";
      """

    When connection open schema transaction for database: typedb
    When typeql schema query
      """
      define
        person owns first-name;
        attribute first-name sub name;
      """
    When transaction commits

    When connection open write transaction for database: typedb
    Then typeql write query; fails with a message containing: "Type-inference was unable to find compatible types for the pair of variables"
      """
      insert
        $p isa person, has ref 0;
      update
        $p has name "Bob";
      """

    When connection open write transaction for database: typedb
    When typeql write query
      """
      insert
        $p isa person, has ref 0;
      update
        $p has first-name "Bob";
      """
    When get answers of typeql read query
      """
      match $p isa person, has name $n;
      """
    Then uniquely identify answer concepts
      | p         | n                   |
      | key:ref:0 | attr:first-name:Bob |


  Scenario: Dependent attributes are not preserved if they are no longer owned after updates
    When typeql write query
      """
      insert
        $r0 isa ref 0;
        $n0 isa name "Alice";
        $r1 isa ref 1;
        $n1 isa name "Bob";
        $p isa person, has $r0, has $n0;
      update
        $p has $r1, has $n1;
      """
    When get answers of typeql read query
      """
      match $p isa person, has name $n;
      """
    Then uniquely identify answer concepts
      | p         | n             |
      | key:ref:1 | attr:name:Bob |
    When get answers of typeql read query
      """
      match
        attribute $t;
        $a isa $t;
      """
    Then uniquely identify answer concepts
      | t          | a             |
      | label:ref  | attr:ref:0    |
      | label:ref  | attr:ref:1    |
      | label:name | attr:name:Bob |

    When typeql write query
      """
      match
        $p1 isa person, has ref 1, has name $n1;
      insert
        $r2 isa ref 2;
        $n2 isa name "Charlie";
        $p3 isa person, has ref 3, has $n1;
      update
        $p1 has $r2, has $n2;
      """
    When get answers of typeql read query
      """
      match $p isa person, has name $n;
      """
    Then uniquely identify answer concepts
      | p         | n                 |
      | key:ref:3 | attr:name:Bob     |
      | key:ref:2 | attr:name:Charlie |
    When get answers of typeql read query
      """
      match
        attribute $t;
        $a isa $t;
      """
    Then uniquely identify answer concepts
      | t          | a                 |
      | label:ref  | attr:ref:0        |
      | label:ref  | attr:ref:1        |
      | label:ref  | attr:ref:2        |
      | label:ref  | attr:ref:3        |
      | label:name | attr:name:Bob     |
      | label:name | attr:name:Charlie |
    When transaction commits

    When connection open read transaction for database: typedb
    When get answers of typeql read query
      """
      match
        attribute $t;
        $a isa $t;
      """
    Then uniquely identify answer concepts
      | t          | a                 |
      | label:ref  | attr:ref:0        |
      | label:ref  | attr:ref:1        |
      | label:ref  | attr:ref:2        |
      | label:ref  | attr:ref:3        |
      | label:name | attr:name:Bob     |
      | label:name | attr:name:Charlie |


  Scenario: Update queries can update multiple 'has'es in a single query
    Given transaction closes
    Given connection open schema transaction for database: typedb
    Given typeql schema query
      """
      define
        person owns first-name, owns surname;
        attribute first-name sub name;
        attribute surname sub name;
      """
    Given transaction commits

    Given connection open write transaction for database: typedb
    Given typeql write query
      """
      insert
        $p0 isa person, has ref 0,
          has name "Alice Morgan",
          has first-name "Alice",
          has surname "Morgan";
        $p1 isa person, has ref 1,
          has name "Bob Marley",
          has first-name "Bob",
          has surname "Marley";
      """
    Given get answers of typeql read query
      """
      match $p isa person, has name $n;
      """
    Given uniquely identify answer concepts
      | p         | n                        |
      | key:ref:0 | attr:name:"Alice Morgan" |
      | key:ref:0 | attr:first-name:"Alice"  |
      | key:ref:0 | attr:surname:"Morgan"    |
      | key:ref:1 | attr:name:"Bob Marley"   |
      | key:ref:1 | attr:first-name:"Bob"    |
      | key:ref:1 | attr:surname:"Marley"    |

    When get answers of typeql write query
      """
      match
        $p isa person, has first-name "Alice";
      update
        $p has surname "Cooper", has ref 20;
      """
    Then uniquely identify answer concepts
      | p          |
      | key:ref:20 |
    When get answers of typeql read query
      """
      match $p isa person, has name $n;
      """
    Then uniquely identify answer concepts
      | p          | n                        |
      | key:ref:20 | attr:name:"Alice Morgan" |
      | key:ref:20 | attr:first-name:"Alice"  |
      | key:ref:20 | attr:surname:"Cooper"    |
      | key:ref:1  | attr:name:"Bob Marley"   |
      | key:ref:1  | attr:first-name:"Bob"    |
      | key:ref:1  | attr:surname:"Marley"    |

    When get answers of typeql write query
      """
      match
        $p isa person;
      update
        $p has first-name "Charlie", has name "404";
      """
    Then uniquely identify answer concepts
      | p          |
      | key:ref:20 |
      | key:ref:1  |
    When get answers of typeql read query
      """
      match $p isa person, has name $n;
      """
    Then uniquely identify answer concepts
      | p          | n                         |
      | key:ref:20 | attr:name:"404"           |
      | key:ref:20 | attr:first-name:"Charlie" |
      | key:ref:20 | attr:surname:"Cooper"     |
      | key:ref:1  | attr:name:"404"           |
      | key:ref:1  | attr:first-name:"Charlie" |
      | key:ref:1  | attr:surname:"Marley"     |

    When get answers of typeql write query
      """
      match
        $p isa person, has name "404";
      update
        $p has first-name "David";
        $p has name "Unknown";
      """
    Then uniquely identify answer concepts
      | p          |
      | key:ref:20 |
      | key:ref:1  |
    When get answers of typeql read query
      """
      match $p isa person, has name $n;
      """
    Then uniquely identify answer concepts
      | p          | n                       |
      | key:ref:20 | attr:name:"Unknown"     |
      | key:ref:20 | attr:first-name:"David" |
      | key:ref:20 | attr:surname:"Cooper"   |
      | key:ref:1  | attr:name:"Unknown"     |
      | key:ref:1  | attr:first-name:"David" |
      | key:ref:1  | attr:surname:"Marley"   |

    Then typeql write query; fails with a message containing: "Constraint '@unique' has been violated"
      """
      match
        $p isa person;
      update
        $p has first-name "Elon";
        $p has ref 0;
      """


  Scenario: Update queries check the actual has cardinality
    Given transaction closes
    Given connection open schema transaction for database: typedb
    Given typeql schema query
      """
      define person owns name @card(0..);
      """
    Given transaction commits

    Given connection open schema transaction for database: typedb
    Given typeql write query
      """
      insert
        $p0 isa person, has ref 0, has name "Alice";
      """
    Given get answers of typeql read query
      """
      match $p isa person, has name $n;
      """
    Given uniquely identify answer concepts
      | p         | n                 |
      | key:ref:0 | attr:name:"Alice" |
    Given transaction commits

    When connection open write transaction for database: typedb
    Then typeql write query; fails with a message containing: "cardinality should not exceed 1"
      """
      match
        $p isa person, has ref 0;
      update
        $p has name "Bob";
      """

    When connection open schema transaction for database: typedb
    When typeql schema query
      """
      redefine person owns name @card(0..1);
      """
    Then typeql write query
      """
      match
        $p isa person, has ref 0;
      update
        $p has name "Bob";
      """

    When get answers of typeql read query
      """
      match $p isa person, has name $n;
      """
    Then uniquely identify answer concepts
      | p         | n               |
      | key:ref:0 | attr:name:"Bob" |


  Scenario: Update has queries on X rows are executed X times
    Given typeql write query
      """
      insert
        $p0 isa person, has ref 0, has name "Alice";
        $p1 isa person, has ref 1, has name "Bob";
        $p2 isa person, has ref 2, has name "Charlie";
      """
    Given get answers of typeql read query
      """
      match $p isa person, has name $n;
      """
    Given uniquely identify answer concepts
      | p         | n                   |
      | key:ref:0 | attr:name:"Alice"   |
      | key:ref:1 | attr:name:"Bob"     |
      | key:ref:2 | attr:name:"Charlie" |

    When typeql write query
      """
      match
        $n isa name;
        $p isa person, has ref 0;
      sort $n asc;
      update
        $p has $n;
      """
    When get answers of typeql read query
      """
      match $p isa person, has name $n;
      """
    Then uniquely identify answer concepts
      | p         | n                   |
      | key:ref:0 | attr:name:"Charlie" |
      | key:ref:1 | attr:name:"Bob"     |
      | key:ref:2 | attr:name:"Charlie" |

    When typeql write query
      """
      match
        $p isa person, has name $n;
      sort $n desc;
      update
        $p has $n;
      """
    When get answers of typeql read query
      """
      match $p isa person, has name $n;
      """
    Then uniquely identify answer concepts
      | p         | n                   |
      | key:ref:0 | attr:name:"Charlie" |
      | key:ref:1 | attr:name:"Bob"     |
      | key:ref:2 | attr:name:"Charlie" |

    When typeql write query
      """
      match
        $p isa person;
        $n isa name;
      sort $n desc;
      update
        $p has $n;
      """
    When get answers of typeql read query
      """
      match $p isa person, has name $n;
      """
    Then uniquely identify answer concepts
      | p         | n               |
      | key:ref:0 | attr:name:"Bob" |
      | key:ref:1 | attr:name:"Bob" |
      | key:ref:2 | attr:name:"Bob" |

    Then typeql write query; fails with a message containing: "Constraint '@unique' has been violated"
      """
      match
        $p isa person;
        $r isa ref;
      update
        $p has $r;
      """

  #######################
  # LINKS (ROLEPLAYING) #
  #######################

  Scenario: Links update on an empty match does nothing
    When get answers of typeql write query
      """
      match
        $p isa person;
        $f isa friendship;
      update
        $f links (friend: $p);
      """
    Then answer size is: 0


  Scenario: Update queries cannot update non-existing roles
    Then typeql write query; fails with a message containing: "Role label not found 'father'"
      """
      insert
        $f isa person, has ref 0;
        $p isa parentship;
      update
        $p links (father: $f);
      """


  Scenario: Update queries cannot update links to zero roleplayers
    Then typeql write query; parsing fails
      """
      insert
        $p isa parentship;
      update
        $p links ();
      """


  Scenario: Links can be updated with a role player variable
    Given typeql write query
      """
      insert
        $_ isa person, has ref 0;
        $_ isa person, has ref 1;
      """
    Given transaction commits
    Given connection open write transaction for database: typedb

    When get answers of typeql write query
      """
      insert
        $f isa friendship, has ref 2;
      match
        $p isa person, has ref 0;
      update
        $f links (friend: $p);
      """
    Then uniquely identify answer concepts
      | f         | p         |
      | key:ref:2 | key:ref:0 |
    When get answers of typeql read query
      """
      match $f isa friendship, links ($p);
      """
    Then uniquely identify answer concepts
      | f         | p         |
      | key:ref:2 | key:ref:0 |

    When get answers of typeql write query
      """
      match
        $p isa person, has ref 1;
        $f isa friendship;
      update
        $f links (friend: $p);
      """
    Then uniquely identify answer concepts
      | f         | p         |
      | key:ref:2 | key:ref:1 |
    When get answers of typeql read query
      """
      match $f isa friendship, links ($p);
      """
    Then uniquely identify answer concepts
      | f         | p         |
      | key:ref:2 | key:ref:1 |
    When transaction commits

    When connection open write transaction for database: typedb
    When get answers of typeql read query
      """
      match $f isa friendship, links ($p);
      """
    Then uniquely identify answer concepts
      | f         | p         |
      | key:ref:2 | key:ref:1 |


  Scenario: Links can be updated without specifying the role if it's unambiguous
    Given typeql write query
      """
      insert
        $_ isa person, has ref 0;
        $_ isa person, has ref 1;
      """
    Given transaction commits
    Given connection open write transaction for database: typedb

    When get answers of typeql write query
      """
      insert
        $f isa friendship, has ref 2;
      match
        $p isa person, has ref 0;
      update
        $f links ($p);
      """
    Then uniquely identify answer concepts
      | f         | p         |
      | key:ref:2 | key:ref:0 |
    When get answers of typeql read query
      """
      match $f isa friendship, links ($r: $p);
      """
    Then uniquely identify answer concepts
      | f         | p         | r                       |
      | key:ref:2 | key:ref:0 | label:friendship:friend |

    When get answers of typeql write query
      """
      match
        $p isa person, has ref 1;
        $f isa friendship;
      update
        $f links ($p);
      """
    Then uniquely identify answer concepts
      | f         | p         |
      | key:ref:2 | key:ref:1 |
    When get answers of typeql read query
      """
      match $f isa friendship, links ($r: $p);
      """
    Then uniquely identify answer concepts
      | f         | p         | r                       |
      | key:ref:2 | key:ref:1 | label:friendship:friend |
    When transaction commits

    When connection open schema transaction for database: typedb
    When get answers of typeql read query
      """
      match $f isa friendship, links ($r: $p);
      """
    Then uniquely identify answer concepts
      | f         | p         | r                       |
      | key:ref:2 | key:ref:1 | label:friendship:friend |

    When typeql schema query
      """
      define friendship relates oldest-friend;
      """
    When transaction commits

    When connection open write transaction for database: typedb
    When get answers of typeql write query
      """
      match
        $p isa person, has ref 0;
        $f isa friendship;
      update
        $f links ($p);
      """
    Then uniquely identify answer concepts
      | f         | p         |
      | key:ref:2 | key:ref:0 |
    When get answers of typeql read query
      """
      match $f isa friendship, links ($r: $p);
      """
    Then uniquely identify answer concepts
      | f         | p         | r                       |
      | key:ref:2 | key:ref:0 | label:friendship:friend |
    When transaction commits

    When connection open schema transaction for database: typedb
    When get answers of typeql read query
      """
      match $f isa friendship, links ($r: $p);
      """
    Then uniquely identify answer concepts
      | f         | p         | r                       |
      | key:ref:2 | key:ref:0 | label:friendship:friend |


  Scenario: Links cannot be updated without specifying the role if it's ambiguous
    Then typeql write query; fails with a message containing: "requires unambiguous role type"
      """
      insert
        $p isa person, has ref 0;
        $r isa parentship, has ref 1;
      update
        $r links ($p);
      """


  Scenario: Can update links from any other write stage, even right after creating a new instance
    When get answers of typeql write query
      """
      insert
        $f isa friendship, has ref 0;
        $p0 isa person, has ref 0;
        $p1 isa person, has ref 1;
        $p2 isa person, has ref 2;
      update
        $f links (friend: $p0);
      update
        $f links (friend: $p1);
      update
        $f links (friend: $p2);
      """
    When get answers of typeql read query
      """
      match $f isa friendship, links ($p);
      """
    Then uniquely identify answer concepts
      | f         | p         |
      | key:ref:0 | key:ref:2 |


  Scenario: Cannot declare new relations and role players variables in an update stage
    Then typeql write query; fails with a message containing: "variable 'f' referenced in the update stage is unavailable"
      """
      insert
        $p isa person, has ref 0;
      update
        $f isa friendship, links ($p);
      """
    When connection open write transaction for database: typedb
    Then typeql write query; fails with a message containing: "variable 'p' referenced in the update stage is unavailable"
      """
      insert
        $f isa friendship;
      update
        $p isa person, has ref 0;
        $f links ($p);
      """
    When connection open write transaction for database: typedb
    Then typeql write query; fails with a message containing: "referenced in the update stage is unavailable"
      """
      update
        $p isa person, has ref 0;
        $f isa friendship, links ($p);
      """


  Scenario Outline: Cannot update links with relates cardinality higher than 1: @card(<card>)
    Given transaction closes
    Given connection open schema transaction for database: typedb
    Given typeql schema query
      """
      define friendship relates friend @card(<card>);
      """
    Given typeql write query
      """
      insert
        $p0 isa person, has ref 0;
        $p1 isa person, has ref 1;
        $p2 isa person, has ref 2;
        $f isa friendship, has ref 0, <links>;
      """
    Given transaction commits

    When connection open write transaction for database: typedb
    Then typeql write query; fails with a message containing: "cardinality should not exceed 1"
      """
      match
        $p0 isa person, has ref 0;
        $p1 isa person, has ref 1;
        $p2 isa person, has ref 2;
        $f isa friendship;
      update
        $f <links-changed>;
      """

    When connection open write transaction for database: typedb
    Then typeql write query; fails with a message containing: "cardinality should not exceed 1"
      """
      match
        $p0 isa person, has ref 0;
        $p1 isa person, has ref 1;
        $p2 isa person, has ref 2;
        $f isa friendship;
      update
        $f <links-changed>;
      """
    Examples:
      | card  | links                            | links-changed                    |
      | 0..   | links (friend: $p0)              | links (friend: $p1)              |
      | 0..10 | links (friend: $p0)              | links (friend: $p1)              |
      | 0..2  | links (friend: $p0)              | links (friend: $p1)              |
      | 0..2  | links (friend: $p0, friend: $p1) | links (friend: $p1)              |
      | 1..   | links (friend: $p0)              | links (friend: $p1)              |
      | 1..2  | links (friend: $p0)              | links (friend: $p1, friend: $p2) |
      | 1..2  | links (friend: $p0)              | links (friend: $p1)              |
      | 2..2  | links (friend: $p0, friend: $p1) | links (friend: $p1, friend: $p2) |
      | 2     | links (friend: $p0, friend: $p1) | links (friend: $p1, friend: $p2) |
      | 2..   | links (friend: $p0, friend: $p1) | links (friend: $p1, friend: $p2) |


  Scenario: Can update links with a correct declared cardinality even if a supertype has a @card(1..)
    Given transaction closes
    Given connection open schema transaction for database: typedb
    Given typeql schema query
      """
      define
        relation aged-friendship sub friendship,
          relates older-friend as friend,
          relates younger-friend as friend;
        friendship relates friend @card(0..);
        person plays aged-friendship:older-friend, plays aged-friendship:younger-friend;
      """
    Given typeql write query
      """
      insert
        $f isa aged-friendship, has ref 0, links (younger-friend: $p0);
        $p0 isa person, has ref 0;
        $p1 isa person, has ref 1;
        $p2 isa person, has ref 2;
      """
    Given transaction commits

    When connection open write transaction for database: typedb
    When get answers of typeql read query
      """
      match $f isa friendship, links ($r: $p);
      """
    Then uniquely identify answer concepts
      | f         | p         | r                                    |
      | key:ref:0 | key:ref:0 | label:aged-friendship:younger-friend |

    When typeql write query
      """
      match
        $f isa aged-friendship, has ref 0;
        $p isa person, has ref 1;
      update
        $f links (older-friend: $p);
      """
    When get answers of typeql read query
      """
      match $f isa friendship, links ($r: $p);
      """
    Then uniquely identify answer concepts
      | f         | p         | r                                    |
      | key:ref:0 | key:ref:0 | label:aged-friendship:younger-friend |
      | key:ref:0 | key:ref:1 | label:aged-friendship:older-friend   |

    When typeql write query
      """
      match
        $f isa aged-friendship, has ref 0;
        $p isa person, has ref 2;
      update
        $f links (younger-friend: $p);
      """
    When get answers of typeql read query
      """
      match $f isa friendship, links ($r: $p);
      """
    Then uniquely identify answer concepts
      | f         | p         | r                                    |
      | key:ref:0 | key:ref:2 | label:aged-friendship:younger-friend |
      | key:ref:0 | key:ref:1 | label:aged-friendship:older-friend   |

    When typeql write query
      """
      match
        $f isa aged-friendship, has ref 0;
        $p isa person, has ref 1;
      update
        $f links (younger-friend: $p);
      """
    When get answers of typeql read query
      """
      match $f isa friendship, links ($r: $p);
      """
    Then uniquely identify answer concepts
      | f         | p         | r                                    |
      | key:ref:0 | key:ref:1 | label:aged-friendship:younger-friend |
      | key:ref:0 | key:ref:1 | label:aged-friendship:older-friend   |
    # We don't need instances since it's a compile-time check
    Then typeql write query; fails with a message containing: "cardinality should not exceed 1"
      """
      match
        $f isa! friendship, has ref 0;
        $p isa person, has ref 0;
      update
        $f links (friend: $p);
      """


  Scenario Outline: Links for card(<card>) can be updated
    Given transaction closes
    Given connection open schema transaction for database: typedb
    Given typeql schema query
      """
      define friendship relates friend @card(<card>);
      """
    Given typeql write query
      """
      insert
        $_ isa person, has ref 0;
        $_ isa person, has ref 1;
      """
    Given transaction commits
    Given connection open write transaction for database: typedb

    When get answers of typeql write query
      """
      insert
        $f isa friendship, has ref 2;
      match
        $p isa person, has ref 0;
      update
        $f links (friend: $p);
      """
    Then uniquely identify answer concepts
      | f         | p         |
      | key:ref:2 | key:ref:0 |
    When get answers of typeql read query
      """
      match $f isa friendship, links ($p);
      """
    Then uniquely identify answer concepts
      | f         | p         |
      | key:ref:2 | key:ref:0 |

    When get answers of typeql write query
      """
      match
        $p isa person, has ref 1;
        $f isa friendship;
      update
        $f links (friend: $p);
      """
    Then uniquely identify answer concepts
      | f         | p         |
      | key:ref:2 | key:ref:1 |
    When get answers of typeql read query
      """
      match $f isa friendship, links ($p);
      """
    Then uniquely identify answer concepts
      | f         | p         |
      | key:ref:2 | key:ref:1 |
    When transaction commits

    When connection open write transaction for database: typedb
    When get answers of typeql read query
      """
      match $f isa friendship, links ($p);
      """
    Then uniquely identify answer concepts
      | f         | p         |
      | key:ref:2 | key:ref:1 |
    Examples:
      | card |
      | 0..1 |
      | 1..1 |


  Scenario: Has update can result in 0 changes if it updates existing data by the same value
    Given typeql write query
      """
      insert
        $p isa person, has ref 0;
        $f isa friendship, has ref 1, links ($p);
      """
    Given transaction commits
    Given connection open write transaction for database: typedb

    When get answers of typeql read query
      """
      match $f isa friendship, links ($p);
      """
    Then uniquely identify answer concepts
      | f         | p         |
      | key:ref:1 | key:ref:0 |

    When get answers of typeql write query
      """
      match
        $p isa person;
        $f isa friendship;
      update
        $f links (friend: $p);
      """
    Then uniquely identify answer concepts
      | f         | p         |
      | key:ref:1 | key:ref:0 |
    When get answers of typeql read query
      """
      match $f isa friendship, links ($r: $p);
      """
    Then uniquely identify answer concepts
      | f         | p         | r                       |
      | key:ref:1 | key:ref:0 | label:friendship:friend |

    When get answers of typeql write query
      """
      match
        $p isa person;
        $f isa friendship;
      update
        $f links ($p);
      """
    Then uniquely identify answer concepts
      | f         | p         |
      | key:ref:1 | key:ref:0 |
    When get answers of typeql read query
      """
      match $f isa friendship, links ($r: $p);
      """
    Then uniquely identify answer concepts
      | f         | p         | r                       |
      | key:ref:1 | key:ref:0 | label:friendship:friend |


  Scenario: Update queries can only use bound variables with 'links'
    Then typeql write query; fails with a message containing: "referenced in the update stage is unavailable"
      """
      update
        $p links (parent: $f);
      """

    When connection open write transaction for database: typedb
    Then typeql write query; fails with a message containing: "variable 'p' referenced in the update stage is unavailable"
      """
      insert
        $f isa person, has ref 0;
      update
        $p links (parent: $f);
      """

    When connection open write transaction for database: typedb
    Then typeql write query; fails with a message containing: "variable 'p' referenced in the update stage is unavailable"
      """
      insert
        $f isa person, has ref 0;
      update
        $p isa parentship, links (parent: $f);
      """

    When connection open write transaction for database: typedb
    Then typeql write query; fails with a message containing: "variable 'f' referenced in the update stage is unavailable"
      """
      insert
        $p isa parentship, has ref 15;
      update
        $p links (parent: $f);
      """

    When connection open write transaction for database: typedb
    When get answers of typeql write query
      """
      insert
        $f isa person, has ref 0;
        $p isa parentship;
      update
        $p links (parent: $f);
      select $f;
      """
    Then uniquely identify answer concepts
      | f         |
      | key:ref:0 |


  Scenario: Update queries are validated similarly to insert queries and do not allow creating abstract links instances
    Given transaction closes
    Given connection open schema transaction for database: typedb
    Given typeql schema query
      """
      define
        friendship relates friend @abstract;
      """
    Given transaction commits

    When connection open write transaction for database: typedb
    Then typeql write query; fails with a message containing: "Type-inference was unable to find compatible types for the pair of variables"
      """
      insert
        $p isa person, has ref 0;
        $f isa friendship, has ref 0;
      update
        $f links (friend: $p);
      """

    When connection open schema transaction for database: typedb
    When typeql schema query
      """
      define
        person plays best-friendship:best-friend;
        relation best-friendship relates best-friend as friend, sub friendship;
      """
    When transaction commits

    When connection open write transaction for database: typedb
    Then typeql write query; fails with a message containing: "Type-inference was unable to find compatible types for the pair of variables"
      """
      insert
        $p isa person, has ref 0;
        $f isa friendship, has ref 0;
      update
        $f links (friend: $p);
      """

    When connection open write transaction for database: typedb
    Then typeql write query; fails with a message containing: "Type-inference was unable to find compatible types for the pair of variables"
      """
      insert
        $p isa person, has ref 0;
        $f isa best-friendship, has ref 0;
      update
        $f links (friend: $p);
      """

    When connection open write transaction for database: typedb
    When typeql write query
      """
      insert
        $p isa person, has ref 0;
        $f isa best-friendship, has ref 0;
      update
        $f links (best-friend: $p);
      """
    When get answers of typeql read query
      """
      match $f isa friendship, links (friend: $p);
      """
    Then uniquely identify answer concepts
      | p         | f         |
      | key:ref:0 | key:ref:0 |
    When transaction commits

    When connection open schema transaction for database: typedb
    When typeql schema query
      """
      define
        person plays eternal-friendship:eternal-friend;
        relation eternal-friendship relates eternal-friend as best-friend, sub best-friendship;
      """
    When transaction commits

    When connection open write transaction for database: typedb
    Then typeql write query; fails with a message containing: "Type-inference was unable to find compatible types for the pair of variables"
      """
      insert
        $p isa person, has ref 1;
        $f isa eternal-friendship, has ref 1;
      update
        $f links (best-friend: $p);
      """

    When connection open write transaction for database: typedb
    When typeql write query
      """
      insert
        $p isa person, has ref 1;
        $f isa eternal-friendship, has ref 1;
      update
        $f links (eternal-friend: $p);
      """
    When get answers of typeql read query
      """
      match $f isa friendship, links (friend: $p);
      """
    Then uniquely identify answer concepts
      | p         | f         |
      | key:ref:0 | key:ref:0 |
      | key:ref:1 | key:ref:1 |
    When transaction commits


  Scenario: Update queries can update multiple 'links'es in a single query
    Given transaction closes
    Given connection open schema transaction for database: typedb
    Given typeql schema query
      """
      define
        person plays friendship:youngest-friend, plays friendship:oldest-friend;
        friendship relates youngest-friend, relates oldest-friend;
      """
    Given transaction commits

    Given connection open write transaction for database: typedb
    Given typeql write query
      """
      insert
        $f0 isa friendship, has ref 0,
          links (oldest-friend: $p0, youngest-friend: $p1, friend: $p0);
        $f1 isa friendship, has ref 1,
          links (oldest-friend: $p1, youngest-friend: $p0, friend: $p2);
        $p0 isa person, has ref 0;
        $p1 isa person, has ref 1;
        $p2 isa person, has ref 2;
      """
    Given get answers of typeql read query
      """
      match $f isa friendship, links ($r: $p);
      """
    Given uniquely identify answer concepts
      | f         | p         | r                                |
      | key:ref:0 | key:ref:0 | label:friendship:friend          |
      | key:ref:0 | key:ref:0 | label:friendship:oldest-friend   |
      | key:ref:0 | key:ref:1 | label:friendship:youngest-friend |
      | key:ref:1 | key:ref:2 | label:friendship:friend          |
      | key:ref:1 | key:ref:1 | label:friendship:oldest-friend   |
      | key:ref:1 | key:ref:0 | label:friendship:youngest-friend |

    When get answers of typeql write query
      """
      match
        $p isa person, has ref 1;
        $f isa friendship, links (youngest-friend: $p);
      update
        $f links (oldest-friend: $p, friend: $p);
      """
    Then uniquely identify answer concepts
      | f         | p         |
      | key:ref:0 | key:ref:1 |
    When get answers of typeql read query
      """
      match $f isa friendship, links ($r: $p);
      """
    Then uniquely identify answer concepts
      | f         | p         | r                                |
      | key:ref:0 | key:ref:1 | label:friendship:friend          |
      | key:ref:0 | key:ref:1 | label:friendship:oldest-friend   |
      | key:ref:0 | key:ref:1 | label:friendship:youngest-friend |
      | key:ref:1 | key:ref:2 | label:friendship:friend          |
      | key:ref:1 | key:ref:1 | label:friendship:oldest-friend   |
      | key:ref:1 | key:ref:0 | label:friendship:youngest-friend |

    When get answers of typeql write query
      """
      insert
        $p isa person, has ref 3;
      match
        $f isa friendship, links (youngest-friend: $p-youngest);
      update
        $f links (youngest-friend: $p, oldest-friend: $p-youngest);
      """
    Then uniquely identify answer concepts
      | f         | p         | p-youngest |
      | key:ref:0 | key:ref:3 | key:ref:1  |
      | key:ref:1 | key:ref:3 | key:ref:0  |
    When get answers of typeql read query
      """
      match $f isa friendship, links ($r: $p);
      """
    Then uniquely identify answer concepts
      | f         | p         | r                                |
      | key:ref:0 | key:ref:1 | label:friendship:friend          |
      | key:ref:0 | key:ref:1 | label:friendship:oldest-friend   |
      | key:ref:0 | key:ref:3 | label:friendship:youngest-friend |
      | key:ref:1 | key:ref:2 | label:friendship:friend          |
      | key:ref:1 | key:ref:0 | label:friendship:oldest-friend   |
      | key:ref:1 | key:ref:3 | label:friendship:youngest-friend |

    When typeql write query
      """
      match
        $p1 isa person, has ref 1;
        $p3 isa person, has ref 3;
        $f isa friendship, links (youngest-friend: $p3);
      update
        $f links (youngest-friend: $p1), links (friend: $p3);
      """
    When get answers of typeql read query
      """
      match $f isa friendship, links ($r: $p);
      """
    Then uniquely identify answer concepts
      | f         | p         | r                                |
      | key:ref:0 | key:ref:3 | label:friendship:friend          |
      | key:ref:0 | key:ref:1 | label:friendship:oldest-friend   |
      | key:ref:0 | key:ref:1 | label:friendship:youngest-friend |
      | key:ref:1 | key:ref:3 | label:friendship:friend          |
      | key:ref:1 | key:ref:0 | label:friendship:oldest-friend   |
      | key:ref:1 | key:ref:1 | label:friendship:youngest-friend |

    When typeql write query
      """
      match
        $p0 isa person, has ref 0;
        $p2 isa person, has ref 2;
        $f isa friendship, links (oldest-friend: $_);
      update
        $f links (youngest-friend: $p0), links (friend: $p2);
      """
    When get answers of typeql read query
      """
      match $f isa friendship, links ($r: $p);
      """
    Then uniquely identify answer concepts
      | f         | p         | r                                |
      | key:ref:0 | key:ref:2 | label:friendship:friend          |
      | key:ref:0 | key:ref:1 | label:friendship:oldest-friend   |
      | key:ref:0 | key:ref:0 | label:friendship:youngest-friend |
      | key:ref:1 | key:ref:2 | label:friendship:friend          |
      | key:ref:1 | key:ref:0 | label:friendship:oldest-friend   |
      | key:ref:1 | key:ref:0 | label:friendship:youngest-friend |


  Scenario: Update queries can update links with relation roleplayers
    Given transaction closes
    Given connection open schema transaction for database: typedb
    Given typeql schema query
      """
      define
        relation family relates parent, relates child, plays friendship:friend, owns ref @key;
        person plays family:parent, plays family:child;
      """
    Given typeql write query
      """
      insert
        $p isa person, has ref 0;
        (parent: $p) isa family, has ref 0;
        (child: $p) isa family, has ref 1;
      """
    Given transaction commits
    Given connection open write transaction for database: typedb

    When get answers of typeql write query
      """
      insert
        $f isa friendship, has ref 2;
      match
        $fam isa family, has ref 0;
      update
        $f links (friend: $fam);
      """
    Then uniquely identify answer concepts
      | f         | fam       |
      | key:ref:2 | key:ref:0 |
    When get answers of typeql read query
      """
      match
        $f isa friendship, links ($friend);
        $friend isa $t;
      """
    Then uniquely identify answer concepts
      | f         | friend    | t            |
      | key:ref:2 | key:ref:0 | label:family |

    When get answers of typeql write query
      """
      match
        $fam isa family, has ref 1;
        $f isa friendship;
      update
        $f links (friend: $fam);
      """
    Then uniquely identify answer concepts
      | f         | fam       |
      | key:ref:2 | key:ref:1 |
    When get answers of typeql read query
      """
      match
        $f isa friendship, links ($friend);
        $friend isa $t;
      """
    Then uniquely identify answer concepts
      | f         | friend    | t            |
      | key:ref:2 | key:ref:1 | label:family |
    When transaction commits

    When connection open write transaction for database: typedb
    When get answers of typeql read query
      """
      match
        $f isa friendship, links ($friend);
        $friend isa $t;
      """
    Then uniquely identify answer concepts
      | f         | friend    | t            |
      | key:ref:2 | key:ref:1 | label:family |

    When get answers of typeql write query
      """
      match
        $p isa person, has ref 0;
        $f isa friendship;
      update
        $f links (friend: $p);
      """
    Then uniquely identify answer concepts
      | f         | p         |
      | key:ref:2 | key:ref:0 |
    When get answers of typeql read query
      """
      match
        $f isa friendship, links ($friend);
        $friend isa $t;
      """
    Then uniquely identify answer concepts
      | f         | friend    | t            |
      | key:ref:2 | key:ref:0 | label:person |
    When transaction commits

    When connection open write transaction for database: typedb
    When get answers of typeql read query
      """
      match
        $f isa friendship, links ($friend);
        $friend isa $t;
      """
    Then uniquely identify answer concepts
      | f         | friend    | t            |
      | key:ref:2 | key:ref:0 | label:person |


  Scenario: Update queries check the actual links cardinality
    Given transaction closes
    Given connection open schema transaction for database: typedb
    Given typeql schema query
      """
      define friendship relates friend @card(0..);
      """
    Given transaction commits

    Given connection open schema transaction for database: typedb
    Given typeql write query
      """
      insert
        $p0 isa person, has ref 0;
        $p1 isa person, has ref 1;
        $f isa friendship, has ref 0, links ($p0);
      """
    Given get answers of typeql read query
      """
      match $f isa friendship, links ($p);
      """
    Given uniquely identify answer concepts
      | f         | p         |
      | key:ref:0 | key:ref:0 |
    Given transaction commits

    When connection open write transaction for database: typedb
    Then typeql write query; fails with a message containing: "cardinality should not exceed 1"
      """
      match
        $f isa friendship;
        $p1 isa person, has ref 1;
      update
        $f links ($p1);
      """

    When connection open schema transaction for database: typedb
    When typeql schema query
      """
      redefine friendship relates friend @card(0..1);
      """
    Then typeql write query
      """
      match
        $f isa friendship;
        $p1 isa person, has ref 1;
      update
        $f links ($p1);
      """

    When get answers of typeql read query
      """
      match $f isa friendship, links ($p);
      """
    Given uniquely identify answer concepts
      | f         | p         |
      | key:ref:0 | key:ref:1 |


  Scenario: Update links queries on X rows are executed X times
    Given typeql write query
      """
      insert
        $p0 isa person, has ref 0;
        $p1 isa person, has ref 1;
        $p2 isa person, has ref 2;
        $f0 isa friendship, has ref 0, links ($p0);
        $f1 isa friendship, has ref 1, links ($p1);
        $f2 isa friendship, has ref 2, links ($p2);
      """
    Given get answers of typeql read query
      """
      match
        $f isa friendship, links ($p);
      """
    Given uniquely identify answer concepts
      | f         | p         |
      | key:ref:0 | key:ref:0 |
      | key:ref:1 | key:ref:1 |
      | key:ref:2 | key:ref:2 |

    When typeql write query
      """
      match
        $p isa person, has ref $r;
        $f isa friendship, has ref 0;
      sort $r asc;
      update
        $f links ($p);
      """
    When get answers of typeql read query
      """
      match
        $f isa friendship, links ($p);
      """
    Then uniquely identify answer concepts
      | f         | p         |
      | key:ref:0 | key:ref:2 |
      | key:ref:1 | key:ref:1 |
      | key:ref:2 | key:ref:2 |

    When typeql write query
      """
      match
        $f isa friendship, links ($p);
        $p has ref $r;
      sort $r desc;
      update
        $f links ($p);
      """
    When get answers of typeql read query
      """
      match
        $f isa friendship, links ($p);
      """
    Then uniquely identify answer concepts
      | f         | p         |
      | key:ref:0 | key:ref:2 |
      | key:ref:1 | key:ref:1 |
      | key:ref:2 | key:ref:2 |

    When typeql write query
      """
      match
        $f isa friendship;
        $p isa person, has ref $r;
      sort $r desc;
      update
        $f links ($p);
      """
    When get answers of typeql read query
      """
      match
        $f isa friendship, links ($p);
      """
    Then uniquely identify answer concepts
      | f         | p         |
      | key:ref:0 | key:ref:0 |
      | key:ref:1 | key:ref:0 |
      | key:ref:2 | key:ref:0 |

  ###############################
  # COMBINATIONS AND EDGE CASES #
  ###############################

  Scenario: Updating an anonymous variable errors
    Then typeql write query; fails with a message containing: "anonymous"
      """
      update
        $_ has $_;
      """

    When connection open write transaction for database: typedb
    Then typeql write query; fails with a message containing: "anonymous"
      """
      insert
        $p isa person, has ref 0, has name "John";
      update
        $p has $_;
      """

    When connection open write transaction for database: typedb
    Then typeql write query; fails with a message containing: "anonymous"
      """
      insert
        $n isa name "John";
      update
        $_ has $n;
      """

    When connection open write transaction for database: typedb
    Then typeql write query; fails with a message containing: "anonymous"
      """
      update
        $_ links (parent: $_);
      """

    When connection open write transaction for database: typedb
    Then typeql write query; fails with a message containing: "anonymous"
      """
      insert
        $p isa parentship;
      update
        $p links (parent: $_);
      """

    When connection open write transaction for database: typedb
    Then typeql write query; fails with a message containing: "anonymous"
      """
      insert
        $p isa person, has ref 0;
      update
        $_ links (parent: $p);
      """


  Scenario: Update queries can update has and links of multiple instances at the same time
    When typeql write query
      """
      insert
        $p0 isa person, has ref 0, has name "Alice";
        $p1 isa person, has ref 1, has name "Bob";
        $f isa friendship, has ref 0, links ($p0);
      """
    When get answers of typeql read query
      """
      match
        $f isa friendship, links ($p);
        $p has name $n;
      """
    Then uniquely identify answer concepts
      | f         | p         | n               |
      | key:ref:0 | key:ref:0 | attr:name:Alice |

    When typeql write query
      """
      match
        $p1 isa person, has name "Bob";
        $f isa friendship, has ref 0;
      update
        $f has ref 5, links ($p1);
      """
    When get answers of typeql read query
      """
      match
        $f isa friendship, links ($p);
        $p has name $n;
      """
    Then uniquely identify answer concepts
      | f         | p         | n             |
      | key:ref:5 | key:ref:1 | attr:name:Bob |

    When typeql write query
      """
      match
        $p0 isa person, has name "Alice";
        $p1 isa person, has name "Bob";
        $f isa friendship, links ($p1);
      update
        $f has ref 0, links ($p0);
        $p0 has name "Charlie", has ref 2;
      """
    When get answers of typeql read query
      """
      match
        $f isa friendship, links ($p);
        $p has name $n;
      """
    Then uniquely identify answer concepts
      | f         | p         | n                 |
      | key:ref:0 | key:ref:2 | attr:name:Charlie |
    When transaction commits

    When connection open read transaction for database: typedb
    When get answers of typeql read query
      """
      match
        $f isa friendship, links ($p);
        $p has name $n;
      """
    Then uniquely identify answer concepts
      | f         | p         | n                 |
      | key:ref:0 | key:ref:2 | attr:name:Charlie |


  Scenario: Update queries cannot update non-existing capabilities, but can update different types matching update constraints
    When typeql write query
      """
      insert
        $p0 isa person, has ref 0, has name "Alice";
        $f isa friendship, has ref 0, links ($p0);
      """
    When get answers of typeql read query
      """
      match
        $f isa friendship, links ($p);
        $p has name $n;
      """
    Then uniquely identify answer concepts
      | f         | p         | n               |
      | key:ref:0 | key:ref:0 | attr:name:Alice |

    When typeql write query
      """
      match
        $p isa person, has ref $_;
        $f isa friendship, has ref $_;
      update
        $f has ref 1;
        $p has ref 2;
      """
    When get answers of typeql read query
      """
      match
        $f isa friendship, links ($p);
        $p has name $n;
      """
    Then uniquely identify answer concepts
      | f         | p         | n               |
      | key:ref:1 | key:ref:2 | attr:name:Alice |

    When typeql write query
      """
      match
        $p has ref $_;
      update
        $p has ref 3;
      """
    When get answers of typeql read query
      """
      match
        $f isa friendship, links ($p);
        $p has name $n;
      """
    Then uniquely identify answer concepts
      | f         | p         | n               |
      | key:ref:3 | key:ref:3 | attr:name:Alice |

    When typeql write query
      """
      match
        $p has name $_;
      update
        $p has name "Bob";
      """
    When get answers of typeql read query
      """
      match
        $f isa friendship, links ($p);
        $p has name $n;
      """
    Then uniquely identify answer concepts
      | f         | p         | n             |
      | key:ref:3 | key:ref:3 | attr:name:Bob |
    When transaction commits

    When connection open write transaction for database: typedb
    Then typeql write query; fails with a message containing: "Left type 'friendship' across constraint 'has' is not compatible with right type 'name'"
      """
      match
        $p has ref $_;
      update
        $p has name "Charlie";
      """

    When connection open write transaction for database: typedb
    Then typeql write query; fails with a message containing: "Left type 'person' across constraint 'links' is not compatible with right type 'friendship:friend'"
      """
      match
        $p has name "Bob";
        $f has ref $_;
      update
        $f links ($p);
      """

  #############################
  # DELETE + INSERT == UPDATE #
  #############################

  Scenario: Update owned attribute without side effects on other owners
    Given get answers of typeql write query
      """
      insert
        $x0 isa person, has name "Alex", has ref 0;
        $y0 isa person, has name "Alex", has ref 1;

        $x1 isa person, has name "Charlie", has ref 2;
        $y1 isa person, has name "Charlie", has ref 3;
      """
    Given uniquely identify answer concepts
      | x0        | y0        | x1        | y1        |
      | key:ref:0 | key:ref:1 | key:ref:2 | key:ref:3 |
    Given transaction commits

    Given connection open write transaction for database: typedb
    When typeql write query
      """
      match
        $x isa person, has ref 1, has $n;
        $n isa name;
      delete
        has $n of $x;
      insert
        $x has name "Bob";
      """
    When typeql write query
      """
      match
        $x isa person, has ref 3, has $n;
        $n isa name;
      update
        $x has name "David";
      """
    Then transaction commits
    Given connection open read transaction for database: typedb
    When get answers of typeql read query
      """
      match $x isa person, has name $n;
      """
    Then uniquely identify answer concepts
      | x         | n                 |
      | key:ref:0 | attr:name:Alex    |
      | key:ref:1 | attr:name:Bob     |
      | key:ref:2 | attr:name:Charlie |
      | key:ref:3 | attr:name:David   |


  Scenario: Update can exchange roleplayers
    Given get answers of typeql write query
      """
      insert
        $x0 isa person, has ref 0;
        $y0 isa person, has ref 1;
        $r0 isa parentship (parent: $x0, child: $y0), has ref 0;

        $x1 isa person, has ref 2;
        $y1 isa person, has ref 3;
        $r1 isa parentship (parent: $x1, child: $y1), has ref 1;
      """
    Given get answers of typeql read query
      """
      match $p isa parentship (parent: $x, child: $y);
      """
    Given uniquely identify answer concepts
      | p         | x         | y         |
      | key:ref:0 | key:ref:0 | key:ref:1 |
      | key:ref:1 | key:ref:2 | key:ref:3 |
    Given transaction commits

    Given connection open write transaction for database: typedb
    When typeql write query
      """
      match
        $p isa parentship (parent: $x, child: $y), has ref $r;
        $r == 0;
      delete
        $p;
      insert
        $q isa parentship (parent: $y, child: $x), has $r;
      """
    When typeql write query
      """
      match
        $p isa parentship (parent: $x, child: $y), has ref $r;
        $r == 1;
      update
        $p links (parent: $y, child: $x);
      """
    When transaction commits
    Given connection open read transaction for database: typedb
    When get answers of typeql read query
      """
      match $p isa parentship (parent: $x, child: $y);
      """
    Then uniquely identify answer concepts
      | p         | x         | y         |
      | key:ref:0 | key:ref:1 | key:ref:0 |
      | key:ref:1 | key:ref:3 | key:ref:2 |


#############
# OPTIONALS #
#############


  Scenario: a has edge depending on an optional binding can be updated
    Given typeql write query
    """
    insert
      $john isa person, has name "John", has ref 0;
      $jane isa person, has name "Jane", has ref 1, has age 33;
    """
    When get answers of typeql write query
    """
    match
      $p isa person;
      try {
        $p has age $age;
        let $new-age-val = $age + 1;
      };
    update try { isset $new-age-val; $p has age == $new-age-val; };
    """
    Then uniquely identify answer concepts
      | p             | age           | new-age-val      |
      | key:name:John | none          | none             |
      | key:name:Jane | attr:age:33   | value:integer:34 |
    Then transaction commits
    Then connection open write transaction for database: typedb
    Then get answers of typeql read query
    """
    match $p isa person, has age $age;
    """
    Then answer size is: 1
    Then get answers of typeql read query
    """
    match $p isa person, has age 33;
    """
    Then answer size is: 0
    Then get answers of typeql read query
    """
    match $p isa person, has age 34;
    """
    Then answer size is: 1


  Scenario: a relation linking an optional player is updated
    Given typeql write query
    """
    insert
      $john isa person, has name "John", has ref 0;
      $jane isa person, has name "Jane", has ref 1;
      $f isa friendship, links ($john), has ref 0;
    """
    When get answers of typeql write query
    """
    match
      $p isa person; $q isa person; not { $p is $q; };
      try { $f links ($p); };
    update
      try { isset $f; $f links (friend: $q); };
    """
    Then uniquely identify answer concepts
      | p         | q         | f         |
      | key:ref:0 | key:ref:1 | key:ref:0 |
      | key:ref:1 | key:ref:0 | none      |
    Then transaction commits
    Then connection open write transaction for database: typedb
    Then get answers of typeql read query
    """
    match $f isa friendship, links($q);
    """
    Then uniquely identify answer concepts
      | q         | f         |
      | key:ref:1 | key:ref:0 |


  Scenario: a try update is only executed if all optional inputs are bound
    Given transaction commits

    Given connection open schema transaction for database: typedb
    When typeql schema query
      """
      define
      entity also-person
        owns name,
        owns age,
        owns ref @key;
      """
    Given transaction commits

    Given connection open write transaction for database: typedb
    Given typeql write query
    """
    insert
      $jane isa person, has ref 0, has name "Jane", has age 33;
      $john isa person, has ref 1, has name "John";
      $anon isa person, has ref 2, has age 45;
    """
    When get answers of typeql write query
    """
    match
      $p isa person, has ref $ref;
      try { $p has age $age; };
      try { $p has name $name; };
    insert $q isa also-person, has $ref;
    update try { isset $age, $name; $q has $age, has $name; };
    """
    Then uniquely identify answer concepts
      | p         | q         | age         | name           |
      | key:ref:0 | key:ref:0 | attr:age:33 | attr:name:Jane |
      | key:ref:1 | key:ref:1 | none        | attr:name:John |
      | key:ref:2 | key:ref:2 | attr:age:45 | none           |
    Then transaction commits

    Then connection open read transaction for database: typedb
    Then get answers of typeql read query
    """
    match $q isa also-person, has age $age;
    """
    Then uniquely identify answer concepts
      | q         | age         |
      | key:ref:0 | attr:age:33 |
    Then get answers of typeql read query
    """
    match $q isa also-person, has name $name;
    """
    Then uniquely identify answer concepts
      | q         | name           |
      | key:ref:0 | attr:name:Jane |


  Scenario: In an update stage, using an optional variable outside a try block errors.
    Then typeql write query; fails with a message containing: "The optional variable 'age' was used in a context where it may fail the branch if unset. Please acknowledge the optionality"
    """
    match
      $john isa person, has name "John";
      $other isa person; try { $other has age $age; };
    update
      $john has $age;
    """


  Scenario: nested try blocks in insert are disallowed
    Given typeql write query; fails
    """
    match $p isa person; try { $p has name $name, has age $age; };
    update try { $p has $name; try { $p has $age; }; };
    """
