# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

#noinspection CucumberUndefinedStep
Feature: TypeQL Optional

  Background: Open connection and create a simple extensible schema
    Given typedb starts
    Given connection opens with default authentication
    Given connection is open: true
    Given connection reset database: typedb
    Given connection open schema transaction for database: typedb
    Given typeql schema query
      """
      define
      entity person owns ref @key,
        plays friendship:friend,
        plays employment:employee,
        owns name,
        owns age;
      entity company owns ref @key,
        plays employment:employer,
        owns name;
      relation friendship owns ref @key,
        relates friend;
      relation employment owns ref @key,
        relates employee,
        relates employer;
      attribute name @independent, value string;
      attribute age @independent, value integer;
      attribute ref value integer;
      """
    Given transaction commits
    Given connection open write transaction for database: typedb

  # TODO: Pipelined writes
  # Feature: insert, delete, put, and update clauses can contain optionals
  # Feature: write clauses operating with all optional variables populated execute as expected
  # Feature: write clauses operating against any empty optional variables do nothing
  # Feature: write clauses cannot contain nested optionals

  # TODO: pipelines
  # Feature: an optionally

  Scenario: a matching optional returns all variables from the optional
    Given typeql write query
      """
      insert
      $x isa person, has name "Jeff", has ref 0;
      $y isa company, has name "Amazon", has ref 1;
      $r isa employment, links (employee: $x, employer: $y), has ref 2;
      """
    Given transaction commits

    Given connection open read transaction for database: typedb
    When get answers of typeql read query
      """
      match $p isa person; $c isa company; try { $r isa employment ($p, $c); };
      """
    Then uniquely identify answer concepts
      | p         | c         | r         |
      | key:ref:0 | key:ref:1 | key:ref:2 |


  Scenario: a non-matching optional returns none of the optional variables
    Given typeql write query
      """
      insert
      $x isa person, has name "Alice", has ref 0;
      $y isa person, has name "Bob", has ref 1;
      """
    Given transaction commits

    Given connection open read transaction for database: typedb
    When get answers of typeql read query
      """
      match $x isa person, has name "Alice"; $y isa person, has name "Bob"; try { $r isa employment ($x, $y); };
      """
    Then answer size is: 1
    Then uniquely identify answer concepts
      | x         | y         | r    |
      | key:ref:0 | key:ref:1 | none |


  Scenario: a partially-matching optional behaves like a non-matching optional and returns none of the optional variables
    Given typeql write query
      """
      insert
      $x isa person, has name "Charlie", has ref 0;
      $y isa company, has name "Google", has ref 1;
      """
    Given transaction commits

    Given connection open read transaction for database: typedb
    When get answers of typeql read query
      """
      match $x isa person, has name "Charlie"; $y isa company, has name "Google"; try { $r isa employment ($x, $y), has ref 100; };
      """
    Then answer size is: 1
    Then uniquely identify answer concepts
      | x         | y         | r    |
      | key:ref:0 | key:ref:1 | none |


  Scenario: a conjunction can contain multiple sibling optionals
    Given typeql write query
      """
      insert
      $x isa person, has name "Dave", has ref 7;
      $y isa company, has name "Microsoft", has ref 8;
      $r1 isa employment, links (employee: $x, employer: $y), has ref 9;
      $z isa company, has name "Apple", has ref 10;
      $r2 isa employment, links (employee: $x, employer: $z), has ref 11;
      """
    Given transaction commits

    Given connection open read transaction for database: typedb
    When get answers of typeql read query
      """
      match
      $x isa person, has name "Dave";
      try { $y isa company, has name "Microsoft"; $r1 isa employment ($x, $y); };
      try { $z isa company, has name "Apple"; $r2 isa employment ($x, $z); };
      """
    Then uniquely identify answer concepts
      | x         | y         | r1        | z          | r2         |
      | key:ref:7 | key:ref:8 | key:ref:9 | key:ref:10 | key:ref:11 |


  Scenario: an optional can contain a nested optional
    Given typeql write query
      """
      insert
      $x isa person, has name "Eve", has ref 12;
      $y isa company, has name "Netflix", has ref 13;
      $r isa employment, links (employee: $x, employer: $y), has ref 14;
      """
    Given transaction commits

    Given connection open read transaction for database: typedb
    When get answers of typeql read query
      """
      match $x isa person, has name "Eve";
      try {
        $y isa company, has name "Netflix";
        $r isa employment ($x, $y);
        try { $y has name "Netflix"; };
      };
      """
    Then uniquely identify answer concepts
      | x          | y          | r          |
      | key:ref:12 | key:ref:13 | key:ref:14 |


  Scenario: an optional cannot be used within a disjunction
    Then typeql read query; fails with a message containing: "must be bound to a value before it's used"
      """
      match $x isa person, has name "Frank";
      {
        $y isa company, has name "Tesla";
        $r isa employment ($x, $y);
      } or {
        try { $y isa company, has name "Tesla"; $r isa employment ($x, $y); };
      };
      """


  Scenario: an optional cannot be used in a negation
    Then typeql read query; fails with a message containing: "Optionals are not allowed in negations"
      """
      match $x isa person; not { try { $y isa company; }; };
      """


  Scenario: sibling optionals may share the same parent variables, but not overlap shared optional variables
    Given typeql write query
      """
      insert
      $x isa person, has name "Eve", has ref 1;
      $y isa company, has name "Netflix", has ref 2;
      $r isa employment, links (employee: $x, employer: $y), has ref 3;
      """
    Given transaction commits

    Given connection open read transaction for database: typedb
    When get answers of typeql read query
    """
      match
      $x isa person, has name "Eve";
      try { $r1 isa employment ($x); };
      try { $r2 isa employment ($x); };
      """
    Then uniquely identify answer concepts
      | x         | r1        | r2        |
      | key:ref:1 | key:ref:3 | key:ref:3 |
    Then typeql read query; fails with a message containing: "The variable 'y' must be bound to a value before it's used"

    """
      match
      $x isa person, has name "Eve";
      try { $y isa company; $r1 isa employment ($x, $y); };
      try { $y isa company; $r2 isa employment ($x, $y); };
      """


  Scenario: an optional variable can be used non-optionally in the next match stage of the pipeline
    Given typeql write query
      """
      insert
      $p1 isa person, has name "Grace", has ref 30;
      $p2 isa person, has name "Somebody", has ref 31;
      $c1 isa company, has name "Uber", has ref 32;
      $r1 isa employment, links (employee: $p1, employer: $c1), has ref 33;
      """
    Given transaction commits

    # a None variable used in a subsequent match causes that row to be filtered out (in this case, the "Somebody" row)
    Given connection open read transaction for database: typedb
    When get answers of typeql read query
      """
      match
      $p isa person;
      try { $c isa company; $r isa employment ($p, $c); };
      match
      isset $c;
      $p has name $name;
      $c has name $company_name;
      """
    Then uniquely identify answer concepts
      | p          | c          | r          | name            | company_name   |
      | key:ref:30 | key:ref:32 | key:ref:33 | attr:name:Grace | attr:name:Uber |

    # a None variable used in a subsequent match, even inside every branch of a Disjunction, causes that row to be filtered out (in this case, the "Somebody" row)
    When get answers of typeql read query
      """
      match
      $p isa person;
      try { $c isa company; $r isa employment ($p, $c); };
      match
      $p has name $name;
      { isset $c; $c has name $attr; $attr == "Uber"; } or { isset $c; $c has ref $attr; $attr == 32; };
      """
    Then uniquely identify answer concepts
      | p          | c          | r          | name            | attr           |
      | key:ref:30 | key:ref:32 | key:ref:33 | attr:name:Grace | attr:name:Uber |
      | key:ref:30 | key:ref:32 | key:ref:33 | attr:name:Grace | attr:ref:32    |

    # a None variable used in a subsequent match can cause only 1 branch of a disjunction to fail
    When get answers of typeql read query
      """
      match
      $p isa person;
      try { $c isa company; $r isa employment ($p, $c); };
      match
      $p has name $name;
      { isset $c; $c has name $attr; $attr == "Uber"; } or { $p has ref 30; } or { $p has ref 31; };
      """
    Then uniquely identify answer concepts
      | p          | c          | r          | name               |
      | key:ref:30 | key:ref:32 | key:ref:33 | attr:name:Grace    |
      | key:ref:31 | none       | none       | attr:name:Somebody |

    # a None variable used in a subsequent match, even inside a Negation, causes that row to be filtered out (in this case, the "Somebody" row)
    When get answers of typeql read query
      """
      match
      $p isa person;
      try { $c isa company; $r isa employment ($p, $c); };
      match
      $p has name $name;
      not { isset $c; $c has ref 100000; };
      """
    Then uniquely identify answer concepts
      | p          | c          | r          | name               |
      | key:ref:30 | key:ref:32 | key:ref:33 | attr:name:Grace    |
      | key:ref:31 | none       | none       | attr:name:Somebody |


  Scenario: an optional variable can be used optionally in the next match stage of the pipeline
    Given typeql write query
      """
      insert
      $p1 isa person, has name "Grace", has ref 30;
      $p2 isa person, has name "Somebody", has ref 31;
      $c1 isa company, has name "Uber", has ref 32;
      $r1 isa employment, links (employee: $p1, employer: $c1), has ref 33;
      """
    Given transaction commits

    Given connection open read transaction for database: typedb
    When get answers of typeql read query
      """
      match
      $p isa person;
      try { $c isa company; $r isa employment ($p, $c); };
      match
      $p has name $name;
      try { isset $c; $c has name $company_name; };
      """
    Then uniquely identify answer concepts
      | p          | c          | r          | name               | company_name   |
      | key:ref:30 | key:ref:32 | key:ref:33 | attr:name:Grace    | attr:name:Uber |
      | key:ref:31 | none       | none       | attr:name:Somebody | none           |

    When get answers of typeql read query
      """
      match
      $p isa person;
      try { $c isa company; $r isa employment ($p, $c); };
      match
      try {
        $p has name $name;
        try { isset $c; $c has name $company_name; };
      };
      """
    Then uniquely identify answer concepts
      | p          | c          | r          | name               | company_name   |
      | key:ref:30 | key:ref:32 | key:ref:33 | attr:name:Grace    | attr:name:Uber |
      | key:ref:31 | none       | none       | attr:name:Somebody | none           |

  # TODO: Test out assigning to optionals  let $x? = f($y);
  # TODO: Test out functions returning optionals: fun f(x) -> { person?, name };
