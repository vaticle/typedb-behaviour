# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

#noinspection CucumberUndefinedStep
Feature: TypeQL Fetch Query

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
      entity nothing;
      entity person
        plays friendship:friend,
        plays employment:employee,
        owns name @card(0..),
        owns person-name @card(0..),
        owns age @card(0..1),
        owns karma @card(0..2),
        owns ref @key;
      entity company
        plays employment:employer,
        owns company-name @card(1..1),
        owns description @card(1..1000),
        owns achievement @card(0..1),
        owns company-achievement @card(0..),
        owns ref @key;
      relation friendship
        relates friend @card(0..),
        owns ref @key;
      relation employment
        relates employee,
        relates employer,
        owns ref @key,
        owns start-date @card(0..),
        owns end-date @card(0..);
      attribute name @abstract, value string;
      attribute person-name sub name;
      attribute company-name sub name;
      attribute description, value string;
      attribute age value integer;
      attribute karma value double;
      attribute ref value integer;
      attribute start-date value datetime;
      attribute end-date value datetime;
      attribute achievement @abstract;
      attribute company-achievement sub achievement, value string;
      """
    Given transaction commits

    Given connection open write transaction for database: typedb
    Given typeql write query
      """
      insert
      $n isa nothing;
      $p1 isa person, has person-name "Alice", has person-name "Allie", has age 10, has karma 123.4567891, has ref 0;
      $p2 isa person, has person-name "Bob", has ref 1;
      $c1 isa company, has company-name "TypeDB", has ref 2, has description "Nice and shy guys", has company-achievement "Green BDD tests for fetch";
      $f1 links (friend: $p1, friend: $p2), isa friendship, has ref 3;
      $e1 links (employee: $p1, employer: $c1), isa employment, has ref 4, has start-date 2020-01-01T13:13:13.999, has end-date 2021-01-01;
      """
    Given transaction commits
    Given connection open read transaction for database: typedb

  ##################
  # SINGLE QUERIES #
  ##################

  Scenario: a fetch with zero projections errors
    Then typeql read query; parsing fails
      """
      match
      $p isa person, has person-name $n;
      fetch;
      """


  Scenario: a fetch with a not available variable errors
    Then typeql read query; fails with a message containing: "The variable 'name' is not available"
      """
      match
        entity $t;
      fetch {
        "name": $name,
      };
      """


  Scenario: a type can be fetched
    When get answers of typeql read query
      """
      match
      $p label person;
      fetch {
        "entity type label": $p
      };
      """
    Then answer size is: 1
    Then answer contains document:
      """
      {
        "entity type label": "person"
      }
      """
    Then answer does not contain document:
      """
      {
        "p": "person"
      }
      """

    When get answers of typeql read query
      """
      match
      $f label friendship;
      fetch {
        "relation type label": $f
      };
      """
    Then answer size is: 1
    Then answer contains document:
      """
      {
        "relation type label": "friendship"
      }
      """

    When get answers of typeql read query
      """
      match
      $n label name;
      fetch {
        "attribute type label": $n
      };
      """
    Then answer size is: 1
    Then answer contains document:
      """
      {
        "attribute type label": "name"
      }
      """

    When get answers of typeql read query
      """
      match
      $f label friendship:friend;
      fetch {
        "role type label": $f
      };
      """
    Then answer size is: 1
    Then answer does not contain document:
      """
      {
        "role type label": "friend"
      }
      """
    Then answer contains document:
      """
      {
        "role type label": "friendship:friend"
      }
      """


  # TODO: Add tests for value types when value types match/fetch is implemented


  Scenario: a variable projection of entities and relations is not acceptable
    Then typeql read query; fails with a message containing: "Fetching entities is not supported"
      """
      match
      entity $t; $x isa $t;
      fetch {
        "entity": $x
      };
      """
    Then typeql read query; fails with a message containing: "Fetching relations is not supported"
      """
      match
      relation $t; $x isa $t;
      fetch {
        "relation": $x
      };
      """


  Scenario: an attribute and a value can be fetched
    When get answers of typeql read query
      """
      match
      $a isa person-name;
      fetch {
        "person": $a
      };
      """
    Then answer size is: 3
    Then answer contains document:
      """
      {
        "person": "Alice"
      }
      """
    Then answer contains document:
      """
      {
        "person": "Allie"
      }
      """
    Then answer contains document:
      """
      {
        "person": "Bob"
      }
      """

    When get answers of typeql read query
      """
      match
      $a isa name;
      let $v = $a;
      fetch {
        "value": $v,
        "attribute": $a
      };
      """
    Then answer size is: 4
    Then answer contains document:
      """
      {
        "value": "Alice",
        "attribute": "Alice"
      }
      """
    Then answer contains document:
      """
      {
        "value": "Allie",
        "attribute": "Allie"
      }
      """
    Then answer contains document:
      """
      {
        "value": "Bob",
        "attribute": "Bob"
      }
      """
    Then answer contains document:
      """
      {
        "value": "TypeDB",
        "attribute": "TypeDB"
      }
      """
    Then answer does not contain document:
      """
      {
        "value": "value",
        "attribute": "value"
      }
      """
    Then answer does not contain document:
      """
      {
        "value": "Allie",
        "attribute": "Alice"
      }
      """


  Scenario: a scalar attribute can be fetched from an object as a scalar value with nulls
    When get answers of typeql read query
      """
      match
      $p isa person;
      fetch {
        "person's age": $p.age
      };
      """
    Then answer size is: 2
    Then answer contains document:
      """
      {
        "person's age": 10
      }
      """
    Then answer contains document:
      """
      {
        "person's age": null
      }
      """
    Then answer does not contain document:
      """
      {
        "person's age": [ 10 ]
      }
      """

    When get answers of typeql read query
      """
      match
      $c isa company;
      fetch {
        "company's achievement": $c.company-achievement
      };
      """
    Then answer size is: 1
    Then answer contains document:
      """
      {
        "company's achievement": "Green BDD tests for fetch"
      }
      """
    Then answer does not contain document:
      """
      {
        "company's achievement": [ "Green BDD tests for fetch" ]
      }
      """


  Scenario: a scalar attribute can be fetched from an object as a list
    When get answers of typeql read query
      """
      match
      $p isa person;
      fetch {
        "person's age": [ $p.age ]
      };
      """
    Then answer size is: 2
    Then answer contains document:
      """
      {
        "person's age": [ 10 ]
      }
      """
    Then answer contains document:
      """
      {
        "person's age": [ ]
      }
      """
    Then answer does not contain document:
      """
      {
        "person's age": 10
      }
      """

    When get answers of typeql read query
      """
      match
      $c isa company;
      fetch {
        "company's achievement": [ $c.company-achievement ]
      };
      """
    Then answer size is: 1
    Then answer contains document:
      """
      {
        "company's achievement": [ "Green BDD tests for fetch" ]
      }
      """
    Then answer does not contain document:
      """
      {
        "company's achievement": "Green BDD tests for fetch"
      }
      """


  Scenario: trying to fetch a scalar value from an object's attribute with non-scalar cardinality leads to error
    Then typeql read query; fails with a message containing: "this attribute can be owned more than 1 time"
      """
      match
        $p isa person;
      fetch {
        "name": $p.person-name
      };
      """


  Scenario: a non-scalar object's attribute can be fetched from as a list
    When get answers of typeql read query
      """
      match
      $p isa person;
      fetch {
        "person": [ $p.person-name ]
      };
      """
    Then answer size is: 2
    Then answer contains document:
      """
      {
        "person": [ "Alice", "Allie" ]
      }
      """
    Then answer contains document:
      """
      {
        "person": [ "Bob" ]
      }
      """


  Scenario: fetch uses results of match stream operators
    When get answers of typeql read query
      """
      match
        $p isa person, has age 10;
      limit 1;
      fetch {
        "person": [ $p.person-name ],
      };
      """
    Then answer size is: 1
    Then answer contains document:
      """
      {
        "person": ["Alice", "Allie"]
      }
      """

    When get answers of typeql read query
      """
      match
        $p isa person, has ref $r;
      sort $r desc;
      limit 1;
      fetch {
        "name": [ $p.person-name ]
      };
      """
    Then answer size is: 1
    Then answer contains document:
      """
      {
        "name": [ "Bob" ]
      }
      """

    When get answers of typeql read query
      """
      match
        $p-type sub person;
        $p isa! $p-type, has $a;
      fetch {
        "person": [ $p.person-name ],
      };
      """
    Then answer size is: 7

    Then typeql read query; fails with a message containing: "The variable 'p' is not available"
      """
      match
        $p-type sub person;
        $p isa! $p-type, has $a;
      select $a;
      fetch {
        "person": [ $p.person-name ],
      };
      """


  Scenario: attributes that can never be owned by any matching type of a variable error
    Then typeql read query; fails with a message containing: "attribute 'company-name' cannot be"
      """
      match
        $p isa person, has person-name "Alice";
      fetch {
        "company name": $p.company-name
      };
      """
    Then typeql read query; fails with a message containing: "attribute 'company-name' cannot be"
      """
      match
        $p isa person, has person-name "Alice";
      fetch {
        "company name": [ $p.company-name ]
      };
      """
    Then typeql read query; fails with a message containing: "attribute 'company-name' cannot be"
      """
      match
        attribute $t; $a isa $t;
      fetch {
        "company name": $a.company-name
      };
      """
    Then typeql read query; fails with a message containing: "attribute 'company-name' cannot be"
      """
      match
        attribute $t; $a isa $t;
      fetch {
        "company name": [ $a.company-name ]
      };
      """


  Scenario: attributes that can never be owned by any matching type of a variable error
    Then typeql read query; fails with a message containing: "attribute 'company-name' cannot be"
      """
      match
        $p isa person, has person-name "Alice";
      fetch {
        "company name": $p.company-name
      };
      """


  Scenario: non-existing fetched attribute produces null
    When get answers of typeql read query
      """
      match
        $p isa person, has ref 1;
      fetch {
        "non-existing age": $p.age
      };
      """
    Then answer size is: 1
    Then answer contains document:
      """
      {
        "non-existing age": null
      }
      """


  Scenario: fetching super attribute type returns its sub attributes
    Given transaction closes
    Given connection open schema transaction for database: typedb
    Given typeql schema query
      """
      define
      attribute surname sub name;
      person owns surname;
      """
    Given transaction commits
    Given connection open write transaction for database: typedb
    Given typeql write query
      """
      match
      $p1 isa person, has person-name "Alice";
      $p2 isa person, has person-name "Bob";
      insert
      $p1 has surname "Cooper";
      $p2 has surname "Marley";
      """
    Given transaction commits
    Given connection open read transaction for database: typedb

    When get answers of typeql read query
      """
      match
        $p isa person;
      fetch {
        "all names": [ $p.name ],
        "person names": [ $p.person-name ],
        "surnames": [ $p.surname ],
        "the only surname": $p.surname
      };
      """
    Then answer size is: 2
    Then answer contains document:
      """
      {
        "all names": [ "Alice", "Allie", "Cooper" ],
        "person names": [ "Alice", "Allie" ],
        "surnames": [ "Cooper" ],
        "the only surname": "Cooper"
      }
      """
    Then answer contains document:
      """
      {
        "all names": [ "Bob", "Marley" ],
        "person names": [ "Bob" ],
        "surnames": [ "Marley" ],
        "the only surname": "Marley"
      }
      """


  Scenario: all attributes of objects can be fetched with correct card representation
    When get answers of typeql read query
      """
      match
        $p has ref $_;
      fetch {
        $p.*
      };
      """
    Then answer size is: 5
    Then answer contains document:
      """
      {
        "person-name": [ "Alice", "Allie" ],
        "age": 10.0,
        "karma": [ 123.4567891 ],
        "ref": 0.0
      }
      """
    Then answer contains document:
      """
      {
        "person-name": [ "Bob" ],
        "ref": 1.0
      }
      """
    Then answer contains document:
      """
      {
        "company-name": "TypeDB",
        "description": [ "Nice and shy guys" ],
        "company-achievement": "Green BDD tests for fetch",
        "ref": 2.0
      }
      """
    Then answer contains document:
      """
      {
        "ref": 3.0
      }
      """
    Then answer contains document:
      """
      {
        "start-date": [ "2020-01-01T13:13:13.999000000" ],
        "end-date": [ "2021-01-01T00:00:00.000000000" ],
        "ref": 4.0
      }
      """

    Then typeql read query; parsing fails
      """
      match
        $p has ref $_;
      fetch {
        "all attributes": $p.*
      };
      """

    When get answers of typeql read query
      """
      match
        $p has ref $_;
      fetch {
        "all attributes": { $p.* }
      };
      """
    Then answer size is: 5
    Then answer contains document:
      """
      {
        "all attributes": {
          "person-name": [ "Alice", "Allie" ],
          "age": 10.0,
          "karma": [ 123.4567891 ],
          "ref": 0.0
        }
      }
      """
    Then answer contains document:
      """
      {
        "all attributes": {
          "person-name": [ "Bob" ],
          "ref": 1.0
        }
      }
      """
    Then answer contains document:
      """
      {
        "all attributes": {
          "company-name": "TypeDB",
          "description": [ "Nice and shy guys" ],
          "company-achievement": "Green BDD tests for fetch",
          "ref": 2.0
        }
      }
      """
    Then answer contains document:
      """
      {
        "all attributes": {
          "ref": 3.0
        }
      }
      """
    Then answer contains document:
      """
      {
        "all attributes": {
          "start-date": [ "2020-01-01T13:13:13.999000000" ],
          "end-date": [ "2021-01-01T00:00:00.000000000" ],
          "ref": 4.0
        }
      }
      """

    When get answers of typeql read query
      """
      match
        $n isa nothing;
      fetch {
        $n.*
      };
      """
    Then answer size is: 1
    Then answer contains document:
      """
      { }
      """

    When get answers of typeql read query
      """
      match
        $n isa nothing;
      fetch {
        "nothing": { $n.* }
      };
      """
    Then answer size is: 1
    Then answer contains document:
      """
      {
        "nothing": { }
      }
      """


  Scenario Outline: attributes and values of <value-type> type can be fetched
    Given transaction closes
    Given connection open schema transaction for database: typedb
    Given typeql schema query
      """
      define
      entity collection owns item;
      attribute item value <value-type>;
      """
    Given transaction commits
    Given connection open write transaction for database: typedb
    Given typeql write query
      """
      insert
        $c isa collection, has item <value>;
      """
    Given transaction commits
    Given connection open read transaction for database: typedb

    When get answers of typeql read query
      """
      match
        $_ isa collection, has $a;
      fetch {
        "a": $a
      };
      """
    Then answer size is: 1
    Then answer contains document:
      """
      {
        "a": <expected>
      }
      """
    Then answer does not contain document:
      """
      {
        "a": <not-expected>
      }
      """

    When get answers of typeql read query
      """
      match
        $_ isa collection, has $a;
        let $v = $a;
      fetch {
        "v": $v
      };
      """
    Then answer size is: 1
    Then answer contains document:
      """
      {
        "v": <expected>
      }
      """
    Then answer does not contain document:
      """
      {
        "v": <not-expected>
      }
      """
    Examples:
      | value-type  | value                                       | expected                                      | not-expected                                 |
      | boolean     | true                                        | true                                          | false                                        |
      | integer     | 12345090                                    | 12345090                                      | 0                                            |
      | double      | 0.0000000001                                | 0.0000000001                                  | 0.000000001                                  |
      | double      | 2.01234567                                  | 2.01234567                                    | 2.01234568                                   |
      | decimal     | 1234567890.0001234567890dec                 | "1234567890.000123456789dec"                  | "1234567890.0001234567890dec"                |
      | decimal     | 0.0000000000000000001dec                    | "0.0000000000000000001dec"                    | "0.000000000000000001dec"                    |
      | string      | "outPUT"                                    | "outPUT"                                      | "output"                                     |
      | date        | 2024-09-20                                  | "2024-09-20"                                  | "2025-09-20"                                 |
      | datetime    | 1999-02-26T12:15:05                         | "1999-02-26T12:15:05.000000000"               | "1999-02-26T12:15:05"                        |
      | datetime    | 1999-02-26T12:15:05.000000001               | "1999-02-26T12:15:05.000000001"               | "1999-02-26T12:15:05.000000000"              |
      | datetime-tz | 2024-09-20T16:40:05.000000001 Europe/London | "2024-09-20T16:40:05.000000001 Europe/London" | "2024-09-20T16:40:05.000000001Europe/London" |
      | datetime-tz | 2024-09-20T16:40:05.000000001+0100          | "2024-09-20T16:40:05.000000001+01:00"         | "2024-09-20T16:40:05.000000001+0100"         |
      | duration    | P1Y10M7DT15H44M5.00394892S                  | "P1Y10M7DT15H44M5.003948920S"                 | "P1Y10M7DT15H44M5.00394892S"                 |
      | duration    | P66W                                        | "P462D"                                       | "P66W"                                       |
    # TODO: Test documents and structs


  Scenario: fetch can have nested documents
    When get answers of typeql read query
      """
        match
          $p isa person, has person-name $name;
          fetch {
            "info": {
              "name": {
                "from entity": [ $p.person-name ],
                "from var": $name,
              },
              "optional age": $p.age,
            }
          };
      """
    Then answer size is: 3
    Then answer contains document:
      """
      {
        "info": {
          "name": {
            "from entity": [ "Alice", "Allie" ],
            "from var": "Alice"
          },
          "optional age": 10
        }
      }
      """
    Then answer contains document:
      """
      {
        "info": {
          "name": {
            "from entity": [ "Alice", "Allie" ],
            "from var": "Allie"
          },
          "optional age": 10
        }
      }
      """
    Then answer contains document:
      """
      {
        "info": {
          "name": {
            "from entity": [ "Bob" ],
            "from var": "Bob"
          },
          "optional age": null
        }
      }
      """


  Scenario: fetch can handle optional objects
    Then get answers of typeql read query
      """
        match
          $p isa person;
          try { employment (employee: $p, employer: $e); };
          fetch {
            "person": { $p.* },
            "employer": { $e.* }  # TODO: What do we do here if $e is optional?
          };
      """
    Then answer size is: 2
    Then answer contains document:
      """
      {
        "person": {
          "person-name": [ "Alice", "Allie" ],
          "age": 10.0,
          "karma": [ 123.4567891 ],
          "ref": 0.0
        },
        "employer": {
          "company-name": "TypeDB",
          "description": [ "Nice and shy guys" ],
          "company-achievement": "Green BDD tests for fetch",
          "ref": 2.0
        }
      }
      """
    Then answer contains document:
      """
      {
        "person": {
          "person-name": [ "Bob" ],
          "ref": 1.0
        },
        "employer": null
      }
      """

    Then get answers of typeql read query
      """
        match
          $p isa person;
          try { employment (employee: $p, employer: $e); };
          fetch {
            "person": { $p.* },
            "employer": [ match $e has company-name $name; return { $name }; ]  # TODO: What do we do here if $e is optional?
          };
      """
    Then answer size is: 2
    Then answer contains document:
      """
      {
        "person": {
          "person-name": [ "Alice", "Allie" ],
          "age": 10.0,
          "karma": [ 123.4567891 ],
          "ref": 0.0
        },
        "employer": [ "TypeDB" ]
      }
      """
    Then answer contains document:
      """
      {
        "person": {
          "person-name": [ "Bob" ],
          "ref": 1.0
        },
        "employer": []
      }
      """


  Scenario: fetch can handle optional objects
    Then get answers of typeql read query
      """
        match
          $p isa person;
          try { $p has karma $k; };
          fetch {
            "name": [ $p.person-name ],
            "adjusted-karma": $k - 100.0 # TODO: What do we do here if $k is optional?
          };
      """
    Then answer size is: 2
    Then answer contains document:
      """
      {
        "name": [ "Alice", "Allie" ],
        "adjusted-karma": 23.4567891
      }
      """
    Then answer contains document:
      """
      {
        "name": [ "Bob" ],
        "adjusted-karma": null
      }
      """


  ##############
  # SUBQUERIES #
  ##############

  Scenario: fetch subqueries should be written inside lists
    Then typeql read query; parsing fails
      """
      match
        $p isa person;
      fetch {
        "list pipeline":
          match
          $p has person-name $n;
          fetch {
            "person name": $n,
          };
      };
      """
    Then typeql read query; parsing fails
      """
      match
        $p isa person;
      fetch {
        "list pipeline": {
            match
            $p has person-name $n;
            fetch {
              "person name": $n,
            };
        }
      };
      """
    Then typeql read query; parsing fails
      """
      match
        $p isa person;
      fetch {
        "list pipeline": (
            match
            $p has person-name $n;
            fetch {
              "person name": $n,
            };
        )
      };
      """
    Then typeql read query
      """
      match
        $p isa person;
      fetch {
        "list pipeline": [
            match
            $p has person-name $n;
            fetch {
              "person name": $n,
            };
        ]
      };
      """


  Scenario: fetch subqueries can add only valid constraints to vars declared in parent queries
    When get answers of typeql read query
      """
      match
        entity $t;
        $p isa! $t;
      fetch {
        "subquery": [
            match
            $p has person-name $pn;
            $pn == "Alice";
            fetch {
              "Alice": $pn
            };
        ],
      };
      """
    Then answer contains document:
      """
      {
        "subquery": [
          {
            "Alice": "Alice"
          }
        ]
      }
      """

    When get answers of typeql read query
      """
      match
        entity $t;
        $p isa! $t;
      fetch {
        "subquery": [
          match
          $p isa person;
          $p has person-name $pn;
          $pn == "Alice";
          fetch {
            "Alice": $pn
          };
        ],
      };
      """
    Then answer contains document:
      """
      {
        "subquery": [
          {
            "Alice": "Alice"
          }
        ]
      }
      """

    Then typeql read query; fails
      """
      match
        entity $t;
        $p isa! $t;
      fetch {
        "subquery": [
            match
            relation $t;
            $p has person-name $pn;
            $pn == "Alice";
            fetch {
              "Alice": $pn
            };
        ],
      };
      """

    Then typeql read query; fails
      """
      match
        entity $t;
        $p isa! $t;
      fetch {
        "subquery": [
            match
            relation $t2;
            $p isa! $t2;
            $p has person-name $pn;
            $pn == "Alice";
            fetch {
              "Alice": $pn
            };
        ],
      };
      """

    Then typeql read query; fails
      """
      match
        entity $t;
        $p isa! $t;
      fetch {
        "subquery": [
            match
            relation $p;
            $p has person-name $pn;
            $pn == "Alice";
            fetch {
              "Alice": $pn
            };
        ],
      };
      """


  Scenario: fetch subqueries produce lists of answers for every parent result respecting parent vars
    When get answers of typeql read query
      """
      match
        $p isa person, has person-name $n;
      fetch {
        "list pipeline": [
            match
            $p has person-name $pn;
            $pn != $n;
            fetch {
              "name": $n,
              "also known as": $pn
            };
        ],
      };
      """
    Then answer size is: 3
    Then answer contains document:
      """
      {
        "list pipeline": [
          {
            "name": "Alice",
            "also known as": "Allie"
          }
        ]
      }
      """
    Then answer contains document:
      """
      {
        "list pipeline": [
          {
            "name": "Allie",
            "also known as": "Alice"
          }
        ]
      }
      """
    Then answer contains document:
      """
      {
        "list pipeline": [ ]
      }
      """

    When transaction closes
    When connection open write transaction for database: typedb
    When typeql write query
      """
      match
        $p isa person, has person-name "Alice", has person-name "Allie";
      insert
        $p has person-name "Alicia";
      """
    When transaction commits
    When connection open read transaction for database: typedb


    When get answers of typeql read query
      """
      match
        $p isa person, has person-name $n;
      fetch {
        "list pipeline": [
            match
              $p has person-name $pn;
              $pn != $n;
            fetch {
              "name": $n,
              "also known as": $pn
            };
        ],
      };
      """
    Then answer size is: 4
    Then answer contains document:
      """
      {
        "list pipeline": [
          {
            "name": "Alice",
            "also known as": "Allie"
          },
          {
            "name": "Alice",
            "also known as": "Alicia"
          }
        ]
      }
      """
    Then answer contains document:
      """
      {
        "list pipeline": [
          {
            "name": "Allie",
            "also known as": "Alice"
          },
          {
            "name": "Allie",
            "also known as": "Alicia"
          }
        ]
      }
      """
    Then answer contains document:
      """
      {
        "list pipeline": [
          {
            "name": "Alicia",
            "also known as": "Alice"
          },
          {
            "name": "Alicia",
            "also known as": "Allie"
          }
        ]
      }
      """
    Then answer contains document:
      """
      {
        "list pipeline": [ ]
      }
      """


  Scenario: Bounds applied to match queries are recursively applied
    When get answers of typeql read query
      """
      match
        $entity label person, plays $role;
        $rel label employment, relates $role;
      fetch {
        "other-employment-roles": [
          match
            $rel relates $other-role;
            not { $other-role is $role; };
          fetch {
            "role": $other-role,
          };
        ]
      };
      """
    Then answer contains document:
      """
      {
        "other-employment-roles": [
          {
            "role": "employment:employer"
          }
        ]
      }
      """
    When get answers of typeql read query
      """
      match
        $entity label person, plays $role;
        $rel label employment, relates $role;
      fetch {
        "role": $role,
        "other-employment-roles": [
          match
            $rel relates $other-role;
            not { $other-role is $role; };
          fetch {
            "other-role": $other-role,
          };
        ]
      };
      """
    Then answer contains document:
      """
      {
        "role": "employment:employee",
        "other-employment-roles": [
          {
            "other-role": "employment:employer"
          }
        ]
      }
      """


  Scenario: same fetch parameter names in one fetch object are not permitted
    Then typeql read query; fails with a message containing: "multiple mappings for one key"
      """
      match
      $p isa! $t, has person-name $n;
      fetch {
        "first": $t,
        "first": $n,
      };
      """
    Then typeql read query; fails with a message containing: "multiple mappings for one key"
      """
      match
      $p isa! $t, has person-name $n;
      fetch {
        "first": $t,
        "first": [ $p.ref ],
      };
      """
    Then typeql read query; fails with a message containing: "multiple mappings for one key"
      """
      match
      $p isa! $t, has person-name $n;
      fetch {
        "first": $n,
        "first": [ $p.person-name ],
      };
      """
    Then typeql read query; fails with a message containing: "multiple mappings for one key"
      """
      match
      $p isa! $t, has person-name $n;
      fetch {
        "first": $n,
        "first": $n,
      };
      """


  Scenario: same fetch parameter names in parent and sub fetches are permitted
    When get answers of typeql read query
      """
      match
      $p isa! $t, has person-name $n;
      fetch {
        "first": $t,
        "second": [
          match
            let $v = $n;
          fetch {
            "first": $n,
            "second": $v
          };
        ],
        "third": [
          match
            $p has age $v;
          fetch {
            "first": $v,
            "second": $n,
            "third": [
              match
                $f links (friend: $p, friend: $friend);
                not { $friend has person-name "Alice"; };
              fetch {
                "first": [ $friend.person-name ]
              };
            ]
          };
        ],
        "fourth": $n
      };
      """
    Then answer contains document:
      """
      {
        "first": "person",
        "second": [
          {
            "first": "Alice",
            "second": "Alice"
          }
        ],
        "third": [
          {
            "first": 10.0,
            "second": "Alice",
            "third": [
              {
                "first": [ "Bob" ]
              }
            ]
          }
        ],
        "fourth": "Alice"
      }
      """


  Scenario: fetch subqueries can contain complex streams
    When get answers of typeql read query
      """
      match
      $p isa! $t, has person-name $n;
      fetch {
        "subquery": [
          match
            $p has person-name $pn;
            let $nv = $n;
            let $pnv = $pn;
            not { $nv == $pnv; };
          sort $nv;
          select $pnv;
          limit 10;
          fetch {
            "another person name": $pnv
          };
        ]
      };
      """
    Then answer contains document:
      """
      {
        "subquery": [
          {
            "another person name": "Alice"
          }
        ]
      }
      """


  Scenario: non-fetch subqueries are not permitted
    Then typeql read query; fails with a message containing: "sub-query: no fetch"
      """
      match
      $p isa! $t, has person-name $n;
      fetch {
        "subquery": [
          match
            let $v = $n;
        ]
      };
      """
    Then typeql read query; fails
      """
      match
      $p isa! $t, has person-name $n;
      fetch {
        "subquery": [
          match
            entity $t;
        ]
      };
      """
    Then typeql read query; fails
      """
      match
      $p isa! $t, has person-name $n;
      fetch {
        "subquery": [
          match
            $p2 isa! $t;
        ]
      };
      """
    Then typeql read query; fails
      """
      match
      $p isa! $t, has person-name $n;
      fetch {
        "subquery": [
          match
            $p2 isa! $t;
          select $p2;
        ]
      };
      """
    Then typeql read query; fails
      """
      match
      $p isa! $t, has person-name $n;
      fetch {
        "subquery": [
          match
            $p has person-name $pn;
            let $nv = $n;
            let $pnv = $pn;
            not { $nv == $pnv; };
          sort $nv;
          select $pnv;
          limit 10;
        ]
      };
      """
    Then typeql read query; fails
      """
      match
      $p isa! $t, has person-name $n;
      fetch {
        "subquery": [
          match
            $p has person-name $pn;
            let $nv = $n;
            let $pnv = $pn;
            not { $nv == $pnv; };
          insert
            $p has person-name "Paul";
        ]
      };
      """
    Then typeql read query; fails
      """
      match
      $p isa! $t, has person-name $n;
      fetch {
        "subquery": [
          match
            $p has person-name $pn;
            let $nv = $n;
            let $pnv = $pn;
            not { $nv == $pnv; };
          insert
            $p has person-name "Paul";
          fetch {
            "Paul's old name": $n
          };
        ]
      };
      """
    Then typeql read query; parsing fails
      """
      match
      $p isa! $t, has person-name $n;
      fetch {
        "subquery": [
          match
            $p has person-name $pn;
            let $nv = $n;
            let $pnv = $pn;
            not { $nv == $pnv; };
          define
            person-name @card(0..99);
        ]
      };
      """
    Then typeql read query; parsing fails
      """
      match
      $p isa! $t, has person-name $n;
      fetch {
        "subquery": [
          match
            $p has person-name $pn;
            let $nv = $n;
            let $pnv = $pn;
            not { $nv == $pnv; };
          define
            person-name @card(0..99);
          fetch {
            "Paul's old name": $n
          };
        ]
      };
      """


  Scenario: a subquery that is not connected to the parent query is permitted
    When get answers of typeql read query
      """
      match
        $p isa person, has person-name $n;
      fetch {
        "all employments multiple times": [
          match
            $r isa employment, has start-date $s;
          fetch {
            "unconnected employment's start date": $s
          };
        ]
      };
      """
    Then answer size is: 3
    Then answer contains document:
      """
      {
        "all employments multiple times": [
          {
            "unconnected employment's start date": "2020-01-01T13:13:13.999000000"
          }
        ]
      }
      """

  #####################
  # VALUE EXPRESSIONS #
  #####################

  Scenario: fetch can use single constants
    When get answers of typeql read query
      """
      match
        $p isa person, has person-name $pn, has karma $k;
        $pn == "Alice";
      fetch {
        "just value": 100,
        "created for": "Alice"
      };
      """
    Then answer size is: 1
    Then answer contains document:
      """
      {
        "just value": 100,
        "created for": "Alice"
      }
      """


  Scenario: fetch can use value operations in expressions
    When get answers of typeql read query
      """
      match
        $p isa person, has person-name $pn, has karma $k;
        $pn == "Alice";
      fetch {
        "excessive karma": $k - 100
      };
      """
    Then answer size is: 1
    Then answer contains document:
      """
      {
        "excessive karma": 23.4567891
      }
      """

  ###########################
  # SINGLE-RETURN FUNCTIONS #
  ###########################

  Scenario: fetch can use a function expression with a single return of attributes
    Given get answers of typeql read query
      """
        with
        fun get_names($p_arg: person) -> { name }:
        match
          $p_arg has person-name $name;
        sort $name;
        return { $name };

        match
          $p isa person;
          let $z in get_names($p);
      """
    Given answer size is: 3
    Given uniquely identify answer concepts
      | p         | z                      |
      | key:ref:0 | attr:person-name:Alice |
      | key:ref:0 | attr:person-name:Allie |
      | key:ref:1 | attr:person-name:Bob   |

    Given get answers of typeql read query
      """
        with
        fun get_age($p_arg: person) -> { age }:
        match
          $p_arg has age $age;
        return { $age };

        match
          $p isa person;
          let $z in get_age($p);
      """
    Given answer size is: 1
    Given uniquely identify answer concepts
      | p         | z           |
      | key:ref:0 | attr:age:10 |

    When get answers of typeql read query
      """
        with
        fun get_name($p_arg: person) -> name:
        match
          $p_arg has person-name $name;
        sort $name;
        return first $name;

        match
          $p isa person;
        fetch {
          "name": get_name($p)
        };
      """
    Then answer size is: 2
    Then answer contains document:
      """
      {
        "name": "Alice"
      }
      """
    Then answer contains document:
      """
      {
        "name": "Bob"
      }
      """

    When get answers of typeql read query
      """
        with
        fun get_name($p_arg: person) -> name:
        match
          $p_arg has person-name $name;
        sort $name;
        return last $name;

        with
        fun get_age($p_arg: person) -> age:
        match
          $p_arg has age $age;
        return first $age;

        match
          $p isa person;
        fetch {
          "name": get_name($p),
          "age": get_age($p)
        };
      """
    Then answer size is: 2
    Then answer contains document:
      """
      {
        "name": "Allie",
        "age": 10
      }
      """
    Then answer contains document:
      """
      {
        "name": "Bob",
        "age": null
      }
      """

    When get answers of typeql read query
      """
        with
        fun get_age($p_arg: person) -> age:
        match
          $p_arg has age $age;
        return first $age;

        match
          $p isa person;
        fetch {
          "age": get_age($p)
        };
      """
    Then answer size is: 2
    Then answer contains document:
      """
      {
        "age": 10
      }
      """
    Then answer contains document:
      """
      {
        "age": null
      }
      """


  Scenario: fetch can use a function expression with a single return of values
    Given get answers of typeql read query
      """
        with
        fun get_names($p_arg: person) -> { string }:
        match
          $p_arg has person-name $name;
          let $value = $name;
        sort $value;
        return { $value };

        match
          $p isa person;
          let $z in get_names($p);
      """
    Given answer size is: 3
    Given uniquely identify answer concepts
      | p         | z                  |
      | key:ref:0 | value:string:Alice |
      | key:ref:0 | value:string:Allie |
      | key:ref:1 | value:string:Bob   |

    Given get answers of typeql read query
      """
        with
        fun get_age($p_arg: person) -> { integer }:
        match
          $p_arg has age $age;
          let $value = $age;
        return { $value };

        match
          $p isa person;
          let $z in get_age($p);
      """
    Given answer size is: 1
    Given uniquely identify answer concepts
      | p         | z                |
      | key:ref:0 | value:integer:10 |

    When get answers of typeql read query
      """
        with
        fun get_name($p_arg: person) -> string:
        match
          $p_arg has person-name $name;
          let $value = $name;
        sort $value;
        return first $value;

        match
          $p isa person;
        fetch {
          "name value": get_name($p)
        };
      """
    Then answer size is: 2
    Then answer contains document:
      """
      {
        "name value": "Alice"
      }
      """
    Then answer contains document:
      """
      {
        "name value": "Bob"
      }
      """

    When get answers of typeql read query
      """
        with
        fun get_name($p_arg: person) -> string:
        match
          $p_arg has person-name $name;
          let $value = $name;
        sort $value;
        return last $value;

        with
        fun get_age($p_arg: person) -> integer:
        match
          $p_arg has age $age;
          let $value = $age;
        return first $value;

        match
          $p isa person;
        fetch {
          "name value": get_name($p),
          "age value": get_age($p)
        };
      """
    Then answer size is: 2
    Then answer contains document:
      """
      {
        "name value": "Allie",
        "age value": 10
      }
      """
    Then answer contains document:
      """
      {
        "name value": "Bob",
        "age value": null
      }
      """

    When get answers of typeql read query
      """
        with
        fun get_age($p_arg: person) -> integer:
        match
          $p_arg has age $age;
          let $value = $age;
        return first $value;

        match
          $p isa person;
        fetch {
          "age value": get_age($p)
        };
      """
    Then answer size is: 2
    Then answer contains document:
      """
      {
        "age value": 10
      }
      """
    Then answer contains document:
      """
      {
        "age value": null
      }
      """


  Scenario: fetching a single-return function expression which actually returns a tuple leads to error
    Then typeql read query; fails with a message containing: "returns a non-scalar result"
      """
        with
        fun get_info($p_arg: person) -> name, age:
        match
          $p_arg has person-name $name, has age $age;
        sort $name;
        return first $name, $age;

        match
          $p isa person;
        fetch {
          "name": get_info($p)
        };
      """


  Scenario: fetching a single-return function expression which actually returns a stream leads to error
    Then typeql read query; fails with a message containing: "must be wrapped in `[]` to collect into a list"
      """
        with
        fun get_names($p_arg: person) -> { name }:
        match
          $p_arg has person-name $name;
        return { $name };

        match
          $p isa person;
        fetch {
          "name": get_names($p)
        };
      """


  Scenario: fetch can use a custom function block with a single return of attributes
    When get answers of typeql read query
      """
        match
          $p isa person;
        fetch {
          "name": (match
            $p has person-name $name;
            sort $name;
            return first $name;)
        };
      """
    Then answer size is: 2
    Then answer contains document:
      """
      {
        "name": "Alice"
      }
      """
    Then answer contains document:
      """
      {
        "name": "Bob"
      }
      """

    When get answers of typeql read query
      """
        match
          $p isa person;
        fetch {
          "name": (
            match
              $p has person-name $v;
              sort $v;
              return last $v;
          ),
          "age": (
            match
              $p has age $v;
              return first $v;
          )
        };
      """
    Then answer size is: 2
    Then answer contains document:
      """
      {
        "name": "Allie",
        "age": 10
      }
      """
    Then answer contains document:
      """
      {
        "name": "Bob",
        "age": null
      }
      """

    When get answers of typeql read query
      """
        match
          $p isa person;
        fetch {
          "age": (match
            $p has age $age;
            return first $age;)
        };
      """
    Then answer size is: 2
    Then answer contains document:
      """
      {
        "age": 10
      }
      """
    Then answer contains document:
      """
      {
        "age": null
      }
      """


  Scenario: fetch can use a custom function block with a single return of values
    When get answers of typeql read query
      """
        match
          $p isa person;
        fetch {
          "name value": (
            match
            $p has person-name $name;
            let $v = $name;
            sort $v;
            return first $v;
          )
        };
      """
    Then answer size is: 2
    Then answer contains document:
      """
      {
        "name value": "Alice"
      }
      """
    Then answer contains document:
      """
      {
        "name value": "Bob"
      }
      """

    When get answers of typeql read query
      """
        match
          $p isa person;
        fetch {
          "name value": (
            match
              $p has person-name $name;
              let $v = $name;
              sort $v;
              return last $v;
          ),
          "age value": (
            match
            $p has age $age;
            let $v = $age;
            return first $v;
          )
        };
      """
    Then answer size is: 2
    Then answer contains document:
      """
      {
        "name value": "Allie",
        "age value": 10
      }
      """
    Then answer contains document:
      """
      {
        "name value": "Bob",
        "age value": null
      }
      """

    When get answers of typeql read query
      """
        match
          $p isa person;
        fetch {
          "age value": (
            match
            $p has age $age;
            let $v = $age;
            return first $v;
          )
        };
      """
    Then answer size is: 2
    Then answer contains document:
      """
      {
        "age value": 10
      }
      """
    Then answer contains document:
      """
      {
        "age value": null
      }
      """


  Scenario: fetch can use a custom function block with a scalar reduce operation result
    When get answers of typeql read query
      """
        match
          $p isa person;
        fetch {
          "names": [
            match
              $p has person-name $name;
              return { $name };
          ],
          "names count listed": [
            match
              $p has person-name $name;
              return count($name);
          ],
          "names count": (
            match
            $p has person-name $name;
            return count($name);
          )
        };
      """
    Then answer size is: 2
    Then answer contains document:
      """
      {
        "names": [ "Alice", "Allie" ],
        "names count listed": [ 2 ],
        "names count": 2
      }
      """
    Then answer contains document:
      """
      {
        "names": [ "Bob" ],
        "names count listed": [ 1 ],
        "names count": 1
      }
      """


  Scenario: fetch can have a subquery returning a list of aggregations
    Given get answers of typeql read query
      """
        with fun get_info($p_arg: person) -> integer, integer, integer:
          match
            $p_arg has person-name $name, has age $age;
            return count($name), sum($age), count($age);

        match
          $p isa person;
          let $x, $y, $z in get_info($p);
      """
    Given answer size is: 2
    Given uniquely identify answer concepts
      | p         | x               | y                | z               |
      | key:ref:0 | value:integer:2 | value:integer:20 | value:integer:2 |
      | key:ref:1 | value:integer:0 | value:integer:0  | value:integer:0 |
    When get answers of typeql read query
      """
        match
          $p isa person;
          fetch {
            "info": [
              match
                $p has person-name $name, has age $age;
                return count($name), sum($age), count($age);
            ]
          };
      """
    Then answer size is: 2
    Then answer contains document:
      """
      {
        "info": [ 2, 20, 2 ]
      }
      """
    Then answer contains document:
      """
      {
        "info": [ 0, 0, 0 ]
      }
      """


  Scenario: fetching a subquery with a returned list of aggregations mixed with non-aggregations leads to error
    Then typeql read query; parsing fails
      """
        match
          $p isa person;
          fetch {
            "info": [
              match
                $p has person-name $name, has age $age;
                return count($name), $age;
            ]
          };
      """

    Then typeql read query; parsing fails
      """
        match
          $p isa person;
          fetch {
            "info": [
              match
                $p has person-name $name, has age $age;
                return $age, count($name);
            ]
          };
      """

    Then typeql read query; parsing fails
      """
        match
          $p isa person;
          fetch {
            "info": [
              match
                $p has person-name $name, has age $age;
                return { count($name), $age };
            ]
          };
      """

    Then typeql read query; parsing fails
      """
        match
          $p isa person;
          fetch {
            "info": [
              match
                $p has person-name $name, has age $age;
                return { count($name), count($age) };
            ]
          };
      """


  Scenario: fetching a list of aggregates for a single function block leads to error
    Then typeql read query; parsing fails
      """
        match
          $p isa person;
          fetch {
            "info": (
              match
                $p has person-name $name, has age $age;
                return count($name), $age;
            )
          };
      """

    Then typeql read query; fails with a message containing: "returns a non-scalar result"
      """
        match
          $p isa person;
          fetch {
            "info": (
              match
                $p has person-name $name, has age $age;
                return count($name), count($age);
            )
          };
      """


  Scenario: fetching a single-return function block which actually returns a tuple leads to error
    Then typeql read query; fails with a message containing: "returns a non-scalar result"
      """
        match
          $p isa person;
        fetch {
          "name": (
            match
            $p has person-name $name, has age $age;
            sort $name;
            return first $name, $age;
          )
        };
      """


  Scenario: fetching a single-return function block which actually returns a stream leads to error
    Then typeql read query; fails with a message containing: "must be wrapped in `[]` to collect into a list"
      """
        match
          $p isa person;
        fetch {
          "names": (
            match
            $p has person-name $name;
            return { $name };
          )
        };
      """

    Then typeql read query; fails with a message containing: "must be wrapped in `[]`"
      """
        match
          $p isa person;
        fetch {
          "names": (
            match
            $p has person-name $name;
            return { $name };
          )
        };
      """

    Then typeql read query; fails with a message containing: "must be wrapped in `[]`"
      """
        match
          $p isa person;
        fetch {
          "names": (
            match
            $p has person-name $v;
            return { $v };
          ),
          "ages": [ match
            $p has age $v;
            return { $v };
          ]
        };
      """


  Scenario: fetch can use a custom function block that is not linked to the main 'match'
    When get answers of typeql read query
      """
        match
            $person isa person;
        fetch {
            "name": (
               match
              $unlinked-person has person-name $name;
              sort $name;
              return first $name;
            )
        };
      """
    Then answer size is: 2
    Then answer contains document:
      """
      {
        "name": "Alice"
      }
      """
    Then answer does not contain document:
      """
      {
        "name": "Bob"
      }
      """


  # TODO: 3.x: Uncomment when expressions allow function calling with math operations
#  Scenario: fetch can use an expression calling a function
#    When get answers of typeql read query
#      """
#        with
#        fun get_karma($p_arg: person) -> double:
#        match
#            $p_arg has karma $k;
#            let $v = $k;
#        return first $v;
#
#        match
#          $p isa person;
#        fetch {
#          "excessive karma": get_karma($p) - 100
#        };
#      """
#    Then answer size is: 2
#    Then answer contains document:
#      """
#      {
#        "excessive karma": 23.4567891
#      }
#      """
#    Then answer contains document:
#      """
#      {
#        "excessive karma": null
#      }
#      """

  ###########################
  # STREAM-RETURN FUNCTIONS #
  ###########################

  Scenario: fetch can use a function expression with a stream return of attributes
    Given get answers of typeql read query
      """
        with
        fun get_names($p_arg: person) -> { name }:
        match
          $p_arg has person-name $name;
        return { $name };

        match
          $p isa person;
          let $z in get_names($p);
      """
    Given answer size is: 3
    Given uniquely identify answer concepts
      | p         | z                      |
      | key:ref:0 | attr:person-name:Alice |
      | key:ref:0 | attr:person-name:Allie |
      | key:ref:1 | attr:person-name:Bob   |

    Given get answers of typeql read query
      """
        with
        fun get_ages($p_arg: person) -> { age }:
        match
          $p_arg has age $age;
        return { $age };

        match
          $p isa person;
          let $z in get_ages($p);
      """
    Given answer size is: 1
    Given uniquely identify answer concepts
      | p         | z           |
      | key:ref:0 | attr:age:10 |

    When get answers of typeql read query
      """
        with
        fun get_names($p_arg: person) -> { name }:
        match
          $p_arg has person-name $name;
        return { $name };

        match
          $p isa person;
        fetch {
          "names": [ get_names($p) ]
        };
      """
    Then answer size is: 2
    Then answer contains document:
      """
      {
        "names": [ "Alice", "Allie" ]
      }
      """
    Then answer contains document:
      """
      {
        "names": [ "Bob" ]
      }
      """

    When get answers of typeql read query
      """
        with
        fun get_ages($p_arg: person) -> { age }:
        match
          $p_arg has age $age;
        return { $age };

        match
          $p isa person;
        fetch {
          "ages": [ get_ages($p) ]
        };
      """
    Then answer size is: 2
    Then answer contains document:
      """
      {
        "ages": [ 10 ]
      }
      """
    Then answer contains document:
      """
      {
        "ages": [ ]
      }
      """


  Scenario: fetch can use a function expression with a stream return of values
    Given get answers of typeql read query
      """
        with
        fun get_names($p_arg: person) -> { string }:
        match
          $p_arg has person-name $name;
          let $v = $name;
        return { $v };

        match
          $p isa person;
          let $z in get_names($p);
      """
    Given answer size is: 3
    Given uniquely identify answer concepts
      | p         | z                  |
      | key:ref:0 | value:string:Alice |
      | key:ref:0 | value:string:Allie |
      | key:ref:1 | value:string:Bob   |

    Given get answers of typeql read query
      """
        with
        fun get_ages($p_arg: person) -> { integer }:
        match
          $p_arg has age $age;
          let $v = $age;
        return { $v };

        match
          $p isa person;
          let $z in get_ages($p);
      """
    Given answer size is: 1
    Given uniquely identify answer concepts
      | p         | z                |
      | key:ref:0 | value:integer:10 |

    When get answers of typeql read query
      """
        with
        fun get_names($p_arg: person) -> { string }:
        match
          $p_arg has person-name $name;
          let $v = $name;
        return { $v };

        match
          $p isa person;
        fetch {
          "name values": [ get_names($p) ]
        };
      """
    Then answer size is: 2
    Then answer contains document:
      """
      {
        "name values": [ "Alice", "Allie" ]
      }
      """
    Then answer contains document:
      """
      {
        "name values": [ "Bob" ]
      }
      """

    When get answers of typeql read query
      """
        with
        fun get_ages($p_arg: person) -> { integer }:
        match
          $p_arg has age $age;
          let $v = $age;
        return { $v };

        match
          $p isa person;
        fetch {
          "age values": [ get_ages($p) ]
        };
      """
    Then answer size is: 2
    Then answer contains document:
      """
      {
        "age values": [ 10 ]
      }
      """
    Then answer contains document:
      """
      {
        "age values": [ ]
      }
      """


  Scenario: fetching a list-return function which actually returns a single result wraps the result into a list
    When get answers of typeql read query
      """
        with
        fun get_name($p_arg: person) -> name:
        match
          $p_arg has person-name $name;
        sort $name;
        return first $name;

        match
          $p isa person;
        fetch {
          "names": [ get_name($p) ]
        };
      """
    Then answer size is: 2
    Then answer contains document:
      """
      {
        "names": [ "Alice" ]
      }
      """
    Then answer contains document:
      """
      {
        "names": [ "Bob" ]
      }
      """


  Scenario: fetching a list-return function expression which actually returns a tuple leads to error
    Then typeql read query; fails with a message containing: "non-scalar result"
      """
        with
        fun get_info($p_arg: person) -> name, age:
        match
          $p_arg has person-name $name, has age $age;
        sort $name;
        return first $name, $age;

        match
          $p isa person;
        fetch {
          "name": [ get_info($p) ]
        };
      """

    Then typeql read query; fails with a message containing: "returns a non-scalar result"
      """
        with
        fun get_info($p_arg: person) -> { name, age }:
        match
          $p_arg has person-name $name, has age $age;
        sort $name;
        return { $name, $age };

        match
          $p isa person;
        fetch {
          "name": [ get_info($p) ]
        };
      """


  Scenario: fetch can use a custom function block with a stream return of attributes
    When get answers of typeql read query
      """
        match
          $p isa person;
        fetch {
          "names": [
            match
              $p has person-name $name;
              return { $name };
          ]
        };
      """
    Then answer size is: 2
    Then answer contains document:
      """
      {
        "names": [ "Alice", "Allie" ]
      }
      """
    Then answer contains document:
      """
      {
        "names": [ "Bob" ]
      }
      """

    When get answers of typeql read query
      """
        match
          $p isa person;
        fetch {
          "names": [
            match
              $p has person-name $v;
              return { $v };
          ],
          "ages": [
            match
              $p has age $v;
              return { $v };
          ]
        };
      """
    Then answer size is: 2
    Then answer contains document:
      """
      {
        "names": [ "Alice", "Allie" ],
        "ages": [ 10 ]
      }
      """
    Then answer contains document:
      """
      {
        "names": [ "Bob" ],
        "ages": [ ]
      }
      """

    When get answers of typeql read query
      """
        match
          $p isa person;
        fetch {
          "ages": [
            match
              $p has age $age;
              return { $age };
          ]
        };
      """
    Then answer size is: 2
    Then answer contains document:
      """
      {
        "ages": [ 10 ]
      }
      """
    Then answer contains document:
      """
      {
        "ages": [ ]
      }
      """


  Scenario: fetch can use a custom function block with a stream return of values
    When get answers of typeql read query
      """
        match
          $p isa person;
        fetch {
          "names": [
            match
              $p has person-name $name;
              let $v = $name;
              return { $v };
          ]
        };
      """
    Then answer size is: 2
    Then answer contains document:
      """
      {
        "names": [ "Alice", "Allie" ]
      }
      """
    Then answer contains document:
      """
      {
        "names": [ "Bob" ]
      }
      """

    When get answers of typeql read query
      """
        match
          $p isa person;
        fetch {
          "names": [
            match
              $p has person-name $name;
              let $v = $name;
              return { $v };
          ],
          "ages": [
            match
              $p has age $age;
              let $v = $age;
              return { $v };
          ]
        };
      """
    Then answer size is: 2
    Then answer contains document:
      """
      {
        "names": [ "Alice", "Allie" ],
        "ages": [ 10 ]
      }
      """
    Then answer contains document:
      """
      {
        "names": [ "Bob" ],
        "ages": [ ]
      }
      """

    When get answers of typeql read query
      """
        match
          $p isa person;
        fetch {
          "ages": [
            match
              $p has age $age;
              let $v = $age;
              return { $v };
          ]
        };
      """
    Then answer size is: 2
    Then answer contains document:
      """
      {
        "ages": [ 10 ]
      }
      """
    Then answer contains document:
      """
      {
        "ages": [ ]
      }
      """


  Scenario: fetching a stream-return function block which actually returns a tuple leads to error
    Then typeql read query; fails with a message containing: "non-scalar non-reduce result"
      """
        match
          $p isa person;
        fetch {
          "name": [
            match
              $p has person-name $name, has age $age;
              return { $name, $age };
          ]
        };
      """

    Then typeql read query; parsing fails
      """
        match
          $p isa person;
        fetch {
          "name": [
            match
              $p has person-name $name, has age $age;
              return $name, $age;
          ]
        };
      """


  Scenario: fetch can use a custom function block with a single return of attributes wrapped in a list
    When get answers of typeql read query
      """
        match
          $p isa person;
        fetch {
          "names": [
            match
              $p has person-name $name;
              sort $name;
              return first $name;
          ]
        };
      """
    Then answer size is: 2
    Then answer contains document:
      """
      {
        "names": [ "Alice" ]
      }
      """
    Then answer contains document:
      """
      {
        "names": [ "Bob" ]
      }
      """

    When get answers of typeql read query
      """
        match
          $p isa person;
        fetch {
          "names": [
            match
              $p has person-name $v;
              sort $v;
              return last $v;
          ],
          "ages": [
            match
              $p has age $v;
              return first $v;
          ]
        };
      """
    Then answer size is: 2
    Then answer contains document:
      """
      {
        "names": [ "Allie" ],
        "ages": [ 10 ]
      }
      """
    Then answer contains document:
      """
      {
        "names": [ "Bob" ],
        "ages": [ ]
      }
      """

  ###################
  # WRITE PIPELINES #
  ###################

  Scenario: fetch can be used in write pipelines
    When get answers of typeql read query
      """
      match
        $p isa person, has person-name $n, has person-name $pn;
        $pn != $n;
      fetch {
        "name": $n,
        "also known as": $pn
      };
      """
    Then answer size is: 2
    Then answer contains document:
      """
      {
        "name": "Alice",
        "also known as": "Allie"
      }
      """
    Then answer contains document:
      """
      {
        "name": "Allie",
        "also known as": "Alice"
      }
      """

    When transaction closes
    When connection open write transaction for database: typedb
    When get answers of typeql write query
      """
      match
        let $n = "John";
        let $pn = "Johnny";
      insert
        $p isa person, has person-name == $n, has person-name == $pn, has ref 66;
      fetch {
        "name": $n,
        "also known as": $pn
      };
      """
    Then answer size is: 1
    Then answer contains document:
      """
      {
        "name": "John",
        "also known as": "Johnny"
      }
      """
    When transaction commits
    When connection open write transaction for database: typedb
    When get answers of typeql write query
      """
      insert
        $n isa person-name "John";
        $pn isa person-name "Jon";
        $p isa person, has $n, has $pn, has ref 77;
      fetch {
        "name": $n,
        "also known as": $pn
      };
      """
    Then answer size is: 1
    Then answer contains document:
      """
      {
        "name": "John",
        "also known as": "Jon"
      }
      """
    When transaction commits
    When connection open read transaction for database: typedb

    When get answers of typeql read query
      """
      match
        $p isa person, has person-name $n, has person-name $pn;
        $pn != $n;
      fetch {
        "name": $n,
        "also known as": $pn
      };
      """
    Then answer size is: 6
    Then answer contains document:
      """
      {
        "name": "Alice",
        "also known as": "Allie"
      }
      """
    Then answer contains document:
      """
      {
        "name": "Allie",
        "also known as": "Alice"
      }
      """
    Then answer contains document:
      """
      {
        "name": "John",
        "also known as": "Johnny"
      }
      """
    Then answer contains document:
      """
      {
        "name": "Johnny",
        "also known as": "John"
      }
      """
    Then answer contains document:
      """
      {
        "name": "Jon",
        "also known as": "John"
      }
      """
    Then answer contains document:
      """
      {
        "name": "John",
        "also known as": "Jon"
      }
      """

  ###############
  # VALIDATION  #
  ###############

  Scenario: Fetch clauses cannot access unavailable variables
    # See: https://github.com/typedb/typedb/issues/7462
    Then typeql read query; fails with a message containing: "The variable 'p' is not available."
      """
      match { $p isa person; } or { $k isa person; }; fetch {"p": $p.name};
      """

    Then typeql read query; fails with a message containing: "The variable 'p' must be bound to a value before it's used"
    """
    with fun name($p: person) -> name:
    match $p has name $n;
    return first $n;

    match { $p isa person; } or { $k isa person; }; fetch {"name": name($p)};

    """

    Then typeql read query; fails with a message containing: "The variable 'p' is not available."
    """
    match { $p isa person; } or { $k isa person; }; fetch { $p.* };
    """
