# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

#noinspection CucumberUndefinedStep
Feature: TypeQL Query with Expressions

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
        owns name @key,
        owns age,
        owns height,
        owns weight;
      attribute name @independent, value string;
      attribute age @independent, value integer;
      attribute height @independent, value integer;
      attribute weight @independent, value integer;

      attribute limit-double @independent, value double;
      """
    Given transaction commits


  Scenario: A value variable must have exactly one assignment constraint in the same branch of a pipeline
    Given connection open write transaction for database: typedb
    Given typeql write query
    """
    insert $p isa person, has name "Lisa", has age 10, has height 180;
    """
    Given transaction commits

    Given connection open read transaction for database: typedb
    Then typeql read query; fails with a message containing: "The variable 'v' must be bound to a value before it's used"
    """
      match
        $x isa person, has age $a, has height $h;
        $v == $a;
        $v > $h;
      select
        $x, $v;
      """
    Given transaction closes

    Given connection open read transaction for database: typedb
    Then typeql read query; fails with a message containing: "Variable 'v' cannot be assigned to multiple times in the same branch."
    """
      match
        $x isa person, has age $a, has height $h;
        let $v = $a * 2;
        let $v = $h * 2;
      select
        $x, $v;
      """
    Then typeql read query; fails with a message containing: "The variable 'v' may not be assigned to, as it was already bound in a previous stage"
    """
      match
        $x isa person, has age $a, has height $h;
        let $v = $a * 2;
      match
        let $v = $h * 2;
      select
        $x, $v;
      """
    Then typeql read query; fails with a message containing: "Variable 'v' cannot be assigned to multiple times in the same branch."
    """
      match
        $x isa person, has age $a, has height $h;
        { let $v = $a * 2; } or { let $v = 0; };
        { let $v = $h * 2; } or { let $v = 1; };
      select
        $x, $v;
      """
    Then typeql read query; fails with a message containing: "The variable 'v' may not be assigned to, as it was already bound in a previous stage"
    """
      match
        $x isa person, has age $a, has height $h;
        { let $v = $a * 2; } or { let $v = 1; };
      match
        { let $v = $h * 2; } or { let $v = 2; };
      select
        $x, $v;
      """
    When get answers of typeql read query
    """
      match
        $x isa person, has age $a, has height $h;
        { let $v = $a * 2; } or { let $v = $h * 2; };
      select
        $v;
      """
    Then uniquely identify answer concepts
      | v                 |
      | value:integer:20  |
      | value:integer:360 |

    When get answers of typeql read query
    """
      match
        $x isa person, has age $a, has height $h;
        { let $v = 12; } or {
          let $v1 = $v;
          { let $v = $a * 2; } or { let $v = $h * 2; };
        };
      select
        $v;
      """
    Then uniquely identify answer concepts
      | v                 |
      | value:integer:12  |
      | value:integer:20  |
      | value:integer:360 |


  Scenario: A value variable must have exactly one assignment constraint recursively
    Given connection open read transaction for database: typedb
    Then typeql read query; fails with a message containing: "Variable 'v' cannot be assigned to multiple times in the same branch."
    """
      match
        $x isa person, has age $a, has height $h;
        let $v = $a + $h;
        not { $a > 10; not { let $v = 10; }; };
      select
        $x, $v;
      """


  Scenario: When no evaluation order can bind the variables in an expression, an error is returned.
    Given connection open read transaction for database: typedb
    Then typeql read query; fails with a message containing: "The variable 'v' must be bound to a value before it's used"
    """
      match
        $x isa person, has age $a, has height $h;
        $v > $h;
        not { let $v = $a / 2; };
      select
        $x, $v;
      """
    Given transaction closes
    Given connection open read transaction for database: typedb
    Then typeql read query; fails with a message containing: "The variable 'v' must be bound to a value before it's used."
    """
      match
        $x isa person, has age $a, has height $h;
        $v > $h;
        try { let $v = $a / 2; };
      select
        $x, $v;
      """
    Given transaction closes

    # verify we recurse properly
    Given connection open read transaction for database: typedb
    Then typeql read query; fails with a message containing: "The required input variables for the following constraints could not be satisfied (there may be a circular dependency)"
    """
      match
        try { let $x = $y + 0;  let $y = $x + 0; };
      select
        $x, $y;
      """
    Given transaction closes

    Given connection open read transaction for database: typedb
    Then typeql read query; fails with a message containing: "The required input variables for the following constraints could not be satisfied (there may be a circular dependency)"
    """
      match
        let $z = 0;
        not { let $x = $y + $z;  let $y = $x + $z; };
      select
        $z;
      """
    Given transaction closes

    Given connection open read transaction for database: typedb
    Then typeql read query; fails with a message containing: "The required input variables for the following constraints could not be satisfied (there may be a circular dependency)"
    """
      match
        { let $x = 0;  let $y = 0; } or
        { let $x = $y + 0;  let $y = $x + 0; };
      select
        $x, $y;
      """
    Given transaction closes


  Scenario: Value variable assignments may not form cycles
    Given connection open read transaction for database: typedb
    Then typeql read query; fails with a message containing: "The required input variables for the following constraints could not be satisfied (there may be a circular dependency)"
    """
      match
        $x isa person, has age $a, has height $h;
        let $v = $a + $v;
      select
        $x, $v;
      """
    Given transaction closes

    Given connection open read transaction for database: typedb
    Then typeql read query; fails with a message containing: "The required input variables for the following constraints could not be satisfied (there may be a circular dependency)"
    """
      match
        $x isa person, has age $a, has height $h;
        let $u = $a + $v;
        let $v = $h + $u;
      select
        $x, $u, $v;
      """
    Given transaction closes

    # Non-cyclic query, just inverted dependencies in two branches.
    Given connection open read transaction for database: typedb
    When get answers of typeql read query
    """
      match
        { let $x = 5; let $y = $x; } or
        { let $y = 6; let $x = $y; };
      select
        $x, $y;
      """
    Then answer size is: 2
    Given transaction closes


  Scenario: Value variables can cross over into negations
    Given connection open write transaction for database: typedb
    Given typeql write query
      """
      insert
      $x isa name "Lisa";
      $y isa age 16;
      $z isa person, has $x, has $y;
      """
    Given transaction commits

    Given connection open read transaction for database: typedb
    When get answers of typeql read query
      """
      match
        $z isa person, has name $x, has age $y;
        let $y2 = $y * 2;
        not { $y > $y2; };
      select $x, $y;
      """
    Then uniquely identify answer concepts
      | x              | y           |
      | attr:name:Lisa | attr:age:16 |


  Scenario: Value variables and concept variables may not share name
    Given connection open write transaction for database: typedb
    Given typeql write query
      """
      insert
      $x isa name "Lisa";
      $y isa age 16;
      $z isa person, has $x, has $y;
      """
    Given transaction commits

    Given connection open read transaction for database: typedb
    Then typeql read query; fails with a message containing: "The variable 'y' cannot be declared as both a 'Value' and as a 'Attribute'"
      """
      match
        $z isa person, has age $y;
        let $y = $y;
      select $z, $y, $y;
      """


  Scenario: All assignments of value variables must have the same value type
    Given connection open write transaction for database: typedb
    Given typeql write query
      """
      insert
      $p isa person, has name "Lisa", has age 16;
      """
    Given transaction commits

    Given connection open read transaction for database: typedb
    Then typeql read query; fails with a message containing: "The variable 'a' must have a single possible value type to be used in an expression"
      """
      match
      $p isa person, has $a;
      let $v = $a;
      """
    Then typeql read query; fails with a message containing: "All assignments of the variable 'v' must have the same value type."
      """
      match
      $p isa person;
      { $p has age $a; let $v = $a; } or
      { $p has name $n; let $v = $n; };
      """
    Then typeql read query; fails with a message containing: "All assignments of the variable 'v' must have the same value type."
      """
      match
      $p isa person, has age $a;
      { let $v = $a * 2; } or
      { let $v = $a / 2.0; };
      """

  Scenario: Test unary minus sign
    Given connection open write transaction for database: typedb
    Given typeql write query
      """
      insert
      $x isa age 16;
      """
    Given transaction commits

    Given connection open read transaction for database: typedb
    When get answers of typeql read query
      """
      match
        $x isa age;
        let $const = -10;
        let $plus-negative = $x + -10;
        let $minus-negative = $x - -10;
      """
    Then uniquely identify answer concepts
      | x           | const             | plus-negative   | minus-negative   |
      | attr:age:16 | value:integer:-10 | value:integer:6 | value:integer:26 |


  Scenario: Test operator definitions - double double
    Given connection open read transaction for database: typedb
    When get answers of typeql read query
    """
      match
        let $a = 6.0 + 3.0;
        let $b = 6.0 - 3.0;
        let $c = 6.0 * 3.0;
        let $d = 6.0 / 3.0;
      select
        $a, $b, $c, $d;
      """
    Then uniquely identify answer concepts
      | a                | b                | c                 | d                |
      | value:double:9.0 | value:double:3.0 | value:double:18.0 | value:double:2.0 |


  Scenario: Test operator definitions - integer integer
    Given connection open read transaction for database: typedb

    When get answers of typeql read query
    """
      match
        let $a = 6 + 3;
        let $b = 6 - 3;
        let $c = 6 * 3;
        let $d = 6 / 3;
      select
        $a, $b, $c, $d;
      """
    Then uniquely identify answer concepts
      | a               | b               | c                | d                |
      | value:integer:9 | value:integer:3 | value:integer:18 | value:double:2.0 |


  Scenario: Test operator definitions - double integer
    Given connection open read transaction for database: typedb

    When get answers of typeql read query
    """
      match
        let $a = 6.0 + 3;
        let $b = 6.0 - 3;
        let $c = 6.0 * 3;
        let $d = 6.0 / 3;
      select
        $a, $b, $c, $d;
      """
    Then uniquely identify answer concepts
      | a                | b                | c                 | d                |
      | value:double:9.0 | value:double:3.0 | value:double:18.0 | value:double:2.0 |


  Scenario: Test operator definitions - integer double
    Given connection open read transaction for database: typedb

    When get answers of typeql read query
    """
      match
        let $a = 6 + 3.0;
        let $b = 6 - 3.0;
        let $c = 6 * 3.0;
        let $d = 6 / 3.0;
      select
        $a, $b, $c, $d;
      """
    Then uniquely identify answer concepts
      | a                | b                | c                 | d                |
      | value:double:9.0 | value:double:3.0 | value:double:18.0 | value:double:2.0 |


  Scenario: Test operator definitions - decimal decimal
    Given connection open read transaction for database: typedb
    When get answers of typeql read query
    """
      match
        let $a = 6.0dec + 3.0dec;
        let $b = 6.0dec - 3.0dec;
        let $c = 6.0dec * 3.0dec;
        let $d = 6.0dec / 3.0dec;
      select
        $a, $b, $c, $d;
      """
    Then uniquely identify answer concepts
      | a                    | b                    | c                     | d                   |
      | value:decimal:9.0dec | value:decimal:3.0dec | value:decimal:18.0dec | value:double:2.0dec |


  Scenario: Test operator definitions - integer decimal
    Given connection open read transaction for database: typedb

    When get answers of typeql read query
    """
      match
        let $a = 6 + 3.0dec;
        let $b = 6 - 3.0dec;
        let $c = 6 * 3.0dec;
        let $d = 6 / 3.0dec;
      select
        $a, $b, $c, $d;
      """
    Then uniquely identify answer concepts
      | a                    | b                    | c                     | d                   |
      | value:decimal:9.0dec | value:decimal:3.0dec | value:decimal:18.0dec | value:double:2.0dec |


  Scenario: Test operator definitions - decimal integer
    Given connection open read transaction for database: typedb
    When get answers of typeql read query
    """
      match
        let $a = 6.0dec + 3;
        let $b = 6.0dec - 3;
        let $c = 6.0dec * 3;
        let $d = 6.0dec / 3;
      select
        $a, $b, $c, $d;
      """
    Then uniquely identify answer concepts
      | a                    | b                    | c                     | d                   |
      | value:decimal:9.0dec | value:decimal:3.0dec | value:decimal:18.0dec | value:double:2.0dec |


  Scenario: Test operator definitions - double decimal
    Given connection open read transaction for database: typedb
    When get answers of typeql read query
    """
      match
        let $a = 6.0 + 3.0dec;
        let $b = 6.0 - 3.0dec;
        let $c = 6.0 * 3.0dec;
        let $d = 6.0 / 3.0dec;
      select
        $a, $b, $c, $d;
      """
    Then uniquely identify answer concepts
      | a                | b                | c                 | d                |
      | value:double:9.0 | value:double:3.0 | value:double:18.0 | value:double:2.0 |


  Scenario: Test operator definitions - decimal double
    Given connection open read transaction for database: typedb
    When get answers of typeql read query
    """
      match
        let $a = 6.0dec + 3.0;
        let $b = 6.0dec - 3.0;
        let $c = 6.0dec * 3.0;
        let $d = 6.0dec / 3.0;
      select
        $a, $b, $c, $d;
      """
    Then uniquely identify answer concepts
      | a                | b                | c                 | d                |
      | value:double:9.0 | value:double:3.0 | value:double:18.0 | value:double:2.0 |


  Scenario: Test operator definitions - date date
    Given connection open read transaction for database: typedb
    When get answers of typeql read query
    """
      match
        let $a = 2027-03-30 - 2026-01-27;
      select
        $a;
      """
    Then uniquely identify answer concepts
      | a                      |
      | value:duration:P1Y2M3D |


  Scenario: Test extreme dates in operator expressions
    Given connection open read transaction for database: typedb
    When get answers of typeql read query
    """
      match
        let $a = +262142-12-31 - -262143-01-01;
      select
        $a;
      """
    Then uniquely identify answer concepts
      | a                             |
      | value:duration:P524285Y11M30D |


  Scenario: Test operator definitions - datetime date
    Given connection open read transaction for database: typedb
    When get answers of typeql read query
    """
      match
        let $a = 2027-03-30T16:05:06.789 - 2026-01-27;
      select
        $a;
      """
    Then uniquely identify answer concepts
      | a                                  |
      | value:duration:P1Y2M3DT16H5M6.789S |


  Scenario: Test operator definitions - datetime datetime
    Given connection open read transaction for database: typedb
    When get answers of typeql read query
    """
      match
        let $a = 2027-03-30T16:05:06.789 - 2026-01-27T12:00:00;
      select
        $a;
      """
    Then uniquely identify answer concepts
      | a                                 |
      | value:duration:P1Y2M3DT4H5M6.789S |


  Scenario: Test extreme values in datetime datetime operator expressions
    Given connection open read transaction for database: typedb
    When get answers of typeql read query
    """
      match
        let $a = +262142-12-31T23:59:59.999999999 - -262143-01-01T00:00:00;
      select
        $a;
      """
    Then uniquely identify answer concepts
      | a                                                 |
      | value:duration:P524285Y11M30DT23H59M59.999999999S |


  Scenario: Test operator definitions - datetime duration
    Given connection open read transaction for database: typedb
    When get answers of typeql read query
    """
      match
        let $a = 2026-01-27T12:00:00 + P1Y2M3DT4H5M6.789S;
        let $b = 2027-03-30T16:05:06.789 - P1Y2M3DT4H5M6.789S;
      select
        $a, $b;
      """
    Then uniquely identify answer concepts
      | a                                      | b                                  |
      | value:datetime:2027-03-30T16:05:06.789 | value:datetime:2026-01-27T12:00:00 |


  Scenario: Test extreme values in datetime duration operator expressions
    Given connection open read transaction for database: typedb
    When get answers of typeql read query
    """
      match
        let $a = +262142-12-31T23:59:59.999999999 - P524285Y11M30DT23H59M59.999999999S;
        let $b = -262143-01-01T00:00:00 + P524285Y11M30DT23H59M59.999999999S;
      select
        $a, $b;
      """
    Then uniquely identify answer concepts
      | a                                     | b                                               |
      | value:datetime:-262143-01-01T00:00:00 | value:datetime:+262142-12-31T23:59:59.999999999 |


  Scenario: Test out of range results in datetime duration operator expressions

    Given connection open read transaction for database: typedb
    Then typeql read query; fails
    """
      match let $a = +262142-12-31T23:59:59.999999999 + PT1S;
    """
    Then typeql read query; fails
    """
      match let $a = -262143-01-01T00:00:00 - PT1S;
    """
    Then typeql read query; fails
    """
      match let $a = +262142-12-31T23:59:59.999999999 - P524285Y11M30DT24H;
    """
    Then typeql read query; fails
    """
      match let $b = -262143-01-01T00:00:00 + P524285Y11M30DT24H;
    """


  Scenario: Test operator definitions - datetime-tz datetime-tz
    Given connection open read transaction for database: typedb
    When get answers of typeql read query
    """
      match
        let $a = 2027-03-30T16:05:06.789 Europe/London - 2026-01-27T12:00:00+01:00;
      select
        $a;
      """
    Then uniquely identify answer concepts
      | a                                 |
      | value:duration:P1Y2M3DT4H5M6.789S |


  Scenario: Test operator definitions - datetime-tz duration
    Given connection open read transaction for database: typedb
    When get answers of typeql read query
    """
      match
        let $a = 2026-01-27T12:00:00+01:00 + P1Y2M3DT4H5M6.789S;
        let $b = 2027-03-30T16:05:06.789 Europe/London - P1Y2M3DT4H5M6.789S;
      select
        $a, $b;
      """
    Then uniquely identify answer concepts
      | a                                               | b                                           |
      | value:datetime-tz:2027-03-30T16:05:06.789+01:00 | value:datetime-tz:2026-01-27T12:00:00+00:00 |


  Scenario: Test operator definitions - string string
    Given connection open read transaction for database: typedb
    When get answers of typeql read query
    """
      match
        let $a = "Hello, " + "world!";
      select
        $a;
      """
    Then uniquely identify answer concepts
      | a                          |
      | value:string:Hello, world! |


  Scenario: Out of range integers fail to parse
    Given connection open read transaction for database: typedb
    Then typeql read query; fails
    """
      match let $a = 9223372036854775808;
    """
    Then typeql read query; fails
    """
      match let $b = -9223372036854775809;
    """


  Scenario: Out of range doubles fail to parse
    Given connection open read transaction for database: typedb
    Then typeql read query; fails
    """
      match let $a = 1.8e308;
    """
    Then typeql read query; fails
    """
      match let $b = -1.8e308;
    """


  Scenario: Out of range decimals fail to parse
    Given connection open read transaction for database: typedb
    Then typeql read query; fails
    """
      match let $a = 9223372036854775808.0dec;
    """
    Then typeql read query; fails
    """
      match let $b = -9223372036854775809.0dec;
    """


  Scenario: Out of range date times fail to parse
    Given connection open read transaction for database: typedb
    Then typeql read query; fails with a message containing: "Invalid date"
    """
      match let $a = +262143-01-01T00:00:00;
    """
    Then typeql read query; fails with a message containing: "Invalid date"
    """
      match let $b = -262144-12-31T23:59:59.999999999;
    """


  Scenario: Out of range date times in a time zone fail to parse
    Given connection open read transaction for database: typedb
    # This is out of local range of NaiveDateTime, but the offset brings it within the UTC NaiveDateTime range
    Then typeql read query; fails with a message containing: "Invalid date"
    """
      match let $a = +262143-01-01T00:00+02:00;
    """
    # This is out of local range of NaiveDateTime, but the offset brings it within the UTC NaiveDateTime range
    Then typeql read query; fails with a message containing: "Invalid date"
    """
      match let $a = -262144-12-31T23:00-02:00;
    """
    # This is within range of local NaiveDateTime, but the offset takes it outside the UTC NaiveDateTime range
    Then typeql read query; fails with a message containing: "Local time +262142-12-31 23:00:00 does not exist in timezone -02:00"
    """
      match let $a = +262142-12-31T23:00-02:00;
    """
    # This is within range of local NaiveDateTime, but the offset takes it outside the UTC NaiveDateTime range
    Then typeql read query; fails with a message containing: "Local time -262143-01-01 00:00:00 does not exist in timezone +02:00"
    """
      match let $a = -262143-01-01T00:00+02:00;
    """


  Scenario: Invalid date times in a time zone fail to parse
    Given connection open read transaction for database: typedb
    # London DST change occurred on 2024-03-31 01:00:00 GMT
    # 2024-03-31 01:00:00 to 02:00:00 do not exist in Europe/London
    Then typeql read query; fails with a message containing: "Local time 2024-03-31 01:30:00 does not exist in timezone Europe/London"
    """
      match
        let $a = 2024-03-31T01:30:00 Europe/London;
      """
    # London DST change occurred on 2024-10-27 02:00:00 BST
    # 2024-10-21 01:00:00 to 02:00:00 occur twice in Europe/London, first in BST, then GMT
    Then typeql read query; fails with a message containing: "Local time 2024-10-27 01:30:00 is ambiguous in timezone Europe/London"
    """
      match
        let $a = 2024-10-27T01:30:00 Europe/London;
      """


  Scenario: Adding one day ignores DST
    Given connection open read transaction for database: typedb
    # London DST change occurred on 2024-03-31 01:00:00 GMT
    When get answers of typeql read query
    """
      match
        let $a = 2024-03-30T12:00:00 Europe/London + P1D;
        let $b = 2024-03-30T12:00:00 Europe/London + PT24H;
      """
    Then uniquely identify answer concepts
      | a                                                   | b                                                   |
      | value:datetime-tz:2024-03-31T12:00:00 Europe/London | value:datetime-tz:2024-03-31T13:00:00 Europe/London |


  Scenario: Adding 24 hours respects DST
    Given connection open read transaction for database: typedb
    # London DST change occurred on 2024-03-31 01:00:00 GMT
    When get answers of typeql read query
    """
      match
        let $a = 2024-03-30T12:00:00 Europe/London + PT24H;
      """
    Then uniquely identify answer concepts
      | a                                                   |
      | value:datetime-tz:2024-03-31T13:00:00 Europe/London |


  Scenario: When addition results in an ambiguous datetime, the earliest possible is used
    Given connection open read transaction for database: typedb
    # London DST change occurred on 2024-10-27 02:00:00 BST
    When get answers of typeql read query
    """
      match
        let $a = 2024-10-26T01:30:00 Europe/London + P1D;
      """
    Then uniquely identify answer concepts
      | a                                           |
      | value:datetime-tz:2024-10-27T01:30:00+01:00 |


  Scenario: When addition results in a datetime that falls in a gap, the datetime is advanced by the length of the gap
    Given connection open read transaction for database: typedb
    # London DST change occurred on 2024-03-31 01:00:00 GMT
    # 2024-03-31 01:00:00 to 02:00:00 do not exist in Europe/London
    When get answers of typeql read query
    """
      match
        let $a = 2024-03-30T01:30:00 Europe/London + P1D;
      """
    Then uniquely identify answer concepts
      | a                                                   |
      | value:datetime-tz:2024-03-31T02:30:00 Europe/London |

    # Samoa switched from -10 to +14 after 29th of December, 2011, skipping 30th of December.
    When get answers of typeql read query
    """
      match
        let $a = 2011-12-29T12:00:00 Pacific/Apia + P1D;
      """
    Then uniquely identify answer concepts
      | a                                                  |
      | value:datetime-tz:2011-12-31T12:00:00 Pacific/Apia |


  Scenario: Test operator definitions - duration duration
    Given connection open read transaction for database: typedb
    When get answers of typeql read query
    """
      match
        let $a = P9Y8M7DT6H5M3.210S + P1Y2M3DT4H5M6.789S;
        let $b = P9Y8M7DT6H5M3.210S - P1Y2M3DT4H5M6.789S;
      select
        $a, $b;
      """
    Then uniquely identify answer concepts
      | a                                      | b                                   |
      | value:duration:P10Y10M10DT10H10M9.999S | value:duration:P8Y6M4DT1H59M56.421S |


  Scenario: Out of range durations fail to parse
    Given connection open read transaction for database: typedb
    Then typeql read query; fails
    """
      match let $a = P524287Y;
    """
    Then typeql read query; fails
    """
      match let $a = P6291433M;
    """


  Scenario: Test out of range results in duration duration operator expressions
    Given connection open read transaction for database: typedb
    Then typeql read query; fails
    """
      match let $a = P6291432M + P1M;
    """
    Then typeql read query; fails
    """
      match let $a = P524288Y + P1M;
    """
    Then typeql read query; fails
    """
      match let $a = PT0S - PT1S;
    """


  Scenario: Test builtin math functions
    Given connection open read transaction for database: typedb
    When get answers of typeql read query
    """
      match
        let $a = floor(3/2);
        let $b = ceil(3/2);
      select
        $a, $b;
      """
    Then uniquely identify answer concepts
      | a               | b               |
      | value:integer:1 | value:integer:2 |

    When get answers of typeql read query
    """
      match
        let $a = round(2/3);
        let $b = abs(-1/2);
      select
        $a, $b;
      """
    Then uniquely identify answer concepts
      | a               | b                |
      | value:integer:1 | value:double:0.5 |
    When get answers of typeql read query
      """
      match
        let $a = max(2, -3);
        let $b = min(2, -3);
        let $c = max(10.2dec, 13.5dec);
        let $d = min(10.2dec, 13.5dec);
        let $e = max(10.2, 13.5);
        let $f = min(10.2, 13.5);
      select
        $a, $b, $c, $d, $e, $f;
      """
    Then uniquely identify answer concepts
      | a               | b                | c                     | d                     | e                 | f                 |
      | value:integer:2 | value:integer:-3 | value:decimal:13.5dec | value:decimal:10.2dec | value:double:13.5 | value:double:10.2 |

  Scenario Outline: Test builtin math function <function> errors
    Given connection open read transaction for database: typedb
    Then typeql read query; fails with a message containing: "<error>"
      """
      match let $x = <function>(<args>);
      """
    Examples:
      | function | args       | error                                  |
      | abs      |            | expects '1' arguments but received '0' |
      | abs      | 10, 12     | expects '1' arguments but received '2' |
      | ceil     |            | expects '1' arguments but received '0' |
      | ceil     | 10, 12     | expects '1' arguments but received '2' |
      | floor    |            | expects '1' arguments but received '0' |
      | floor    | 10, 12     | expects '1' arguments but received '2' |
      | round    |            | expects '1' arguments but received '0' |
      | round    | 10, 12     | expects '1' arguments but received '2' |
      | min      |            | expects '2' arguments but received '0' |
      | min      | 10         | expects '2' arguments but received '1' |
      | min      | 10, 11, 12 | expects '2' arguments but received '3' |
      | max      |            | expects '2' arguments but received '0' |
      | max      | 10         | expects '2' arguments but received '1' |
      | max      | 10, 11, 12 | expects '2' arguments but received '3' |
      | min      | 10, 12.2   | expects matching argument types        |
      | max      | 10, 12.2   | expects matching argument types        |


  Scenario Outline: test builtin unary function <function> when applied to <type> produces correct result
    Given connection open read transaction for database: typedb
    When get answers of typeql read query
    """
      match
        let $in = <val>;
        let $out = <function>($in);
      select
        $in, $out;
      """
    Then uniquely identify answer concepts
      | in                 | out                              |
      | value:<type>:<val> | value:<output-type>:<output-val> |
    Examples:
      | function | type    | val             | output-type | output-val |
      | abs      | integer | 6               | integer     | 6          |
      | abs      | integer | 0               | integer     | 0          |
      | abs      | integer | -1              | integer     | 1          |
      | abs      | double  | 6.4             | double      | 6.4        |
      | abs      | double  | 0.0             | double      | 0.0        |
      | abs      | double  | -1.3            | double      | 1.3        |
      | ceil     | double  | 11.0            | integer     | 11         |
      | ceil     | double  | 11.5            | integer     | 12         |
      | ceil     | double  | 12.5            | integer     | 13         |
      | ceil     | double  | -11.5           | integer     | -11        |
      | ceil     | double  | -12.5           | integer     | -12        |
      | floor    | double  | 11.0            | integer     | 11         |
      | floor    | double  | 11.5            | integer     | 11         |
      | floor    | double  | 12.5            | integer     | 12         |
      | floor    | double  | -11.5           | integer     | -12        |
      | floor    | double  | -12.5           | integer     | -13        |
      | round    | double  | 11.0            | integer     | 11         |
      | round    | double  | 11.5            | integer     | 12         |
      | round    | double  | 12.5            | integer     | 12         |
      | round    | double  | -11.5           | integer     | -12        |
      | round    | double  | -12.5           | integer     | -12        |
      | abs      | decimal | 6.4dec          | decimal     | 6.4dec     |
      | abs      | decimal | 0.0dec          | decimal     | 0.0dec     |
      | abs      | decimal | -1.3dec         | decimal     | 1.3dec     |
      | ceil     | decimal | 11.0dec         | integer     | 11         |
      | ceil     | decimal | 11.5dec         | integer     | 12         |
      | ceil     | decimal | 12.5dec         | integer     | 13         |
      | ceil     | decimal | -11.5dec        | integer     | -11        |
      | ceil     | decimal | -12.5dec        | integer     | -12        |
      | floor    | decimal | 11.0dec         | integer     | 11         |
      | floor    | decimal | 11.5dec         | integer     | 11         |
      | floor    | decimal | 12.5dec         | integer     | 12         |
      | floor    | decimal | -11.5dec        | integer     | -12        |
      | floor    | decimal | -12.5dec        | integer     | -13        |
      | round    | decimal | 11.0dec         | integer     | 11         |
      | round    | decimal | 11.5dec         | integer     | 12         |
      | round    | decimal | 12.5dec         | integer     | 12         |
      | round    | decimal | -11.5dec        | integer     | -12        |
      | round    | decimal | -12.5dec        | integer     | -12        |
      | len      | string  | ""              | integer     | 0          |
      | len      | string  | "Hello, world!" | integer     | 13         |
      | len      | string  | "こんにちは"         | integer     | 5          |
      | len      | string  | "❤️‍🔥"         | integer     | 4          |
      | len      | string  | "⭐"             | integer     | 1          |


  Scenario Outline: test intrinsic unary function <function> when applied to <type> produces correct result
    Given connection open read transaction for database: typedb
    Then typeql read query; fails with a message containing: "Built-in function '<namespaced>' cannot be applied to arguments of type '<type>'."
    """
      match
        let $a = <function>(<val>);
      """
    Examples:
      | function | type    | val    | namespaced       |
      | ceil     | integer | 0      | std::math::ceil  |
      | floor    | integer | 0      | std::math::floor |
      | round    | integer | 0      | std::math::round |
      | len      | integer | 0      | std::string::len |
      | len      | double  | 0.0    | std::string::len |
      | len      | decimal | 0.0dec | std::string::len |


  Scenario: Test operators on variables
    Given connection open write transaction for database: typedb
    Given typeql write query
      """
      insert $x isa person,
          has name 'Steve',
          has age 20,
          has height 160,
          has weight 60;
      """
    Given transaction commits

    Given connection open read transaction for database: typedb
    When get answers of typeql read query
      """
      match
        $p isa person, has name $name,
         has age $a, has weight $w, has height $h;

        let $bmi = $w/($h/100 * $h/100);

        let $days-since-18 = ($a - 18) * 365.25;
        let $hours-per-day = 24;
        let $hours-since-18 = $hours-per-day * $days-since-18;
      select
        $name, $hours-since-18, $bmi;
      """

    Then uniquely identify answer concepts
      | name            | hours-since-18       | bmi                  |
      | attr:name:Steve | value:double:17532.0 | value:double:23.4375 |


  Scenario: Test predicates between value variables and constants
    Given connection open write transaction for database: typedb
    Given typeql write query
      """
      insert
        $x isa person, has name "b25.0", has height 160, has weight 64;
        $y isa person, has name "b22.2", has height 180, has weight 72;
        $z isa person, has name "b26.1", has height 175, has weight 80;
        $l isa limit-double 25;
      """
    Given transaction commits

    Given connection open read transaction for database: typedb
    When get answers of typeql read query
      """
      match
        $p isa person, has name $name, has height $h, has weight $w;
        let $bmi = $w/($h/100 * $h/100);
        $bmi < 25;
      select
        $name;
      """

    Then uniquely identify answer concepts
      | name            |
      | attr:name:b22.2 |

    When get answers of typeql read query
      """
      match
        $p isa person, has name $name, has height $h, has weight $w;
        let $bmi = $w/($h/100 * $h/100);
        $bmi <= 25;
      select
        $name;
      """

    Then uniquely identify answer concepts
      | name            |
      | attr:name:b22.2 |
      | attr:name:b25.0 |


  Scenario: Test predicates between value variables and value variables
    Given connection open write transaction for database: typedb
    Given typeql write query
      """
      insert
        $x isa person, has name "b25.0", has height 160, has weight 64;
        $y isa person, has name "b22.2", has height 180, has weight 72;
        $z isa person, has name "b26.1", has height 175, has weight 80;
        $l isa limit-double 25;
      """
    Given transaction commits

    Given connection open read transaction for database: typedb
    When get answers of typeql read query
      """
      match
        $p isa person, has name $name, has height $h, has weight $w;
        let $bmi = $w/($h/100 * $h/100);
        let $lim = 25;
        $bmi < $lim;
      select
        $name;
      """

    Then uniquely identify answer concepts
      | name            |
      | attr:name:b22.2 |

    When get answers of typeql read query
      """
      match
        $p isa person, has name $name, has height $h, has weight $w;
        let $bmi = $w/($h/100 * $h/100);
        let $lim = 25;
        $bmi <= $lim;
      select
        $name;
      """

    Then uniquely identify answer concepts
      | name            |
      | attr:name:b22.2 |
      | attr:name:b25.0 |


  Scenario: Test predicates between value variables and thing variables
    Given connection open write transaction for database: typedb
    Given typeql write query
      """
      insert
        $x isa person, has name "b25.0", has height 160, has weight 64;
        $y isa person, has name "b22.2", has height 180, has weight 72;
        $z isa person, has name "b26.1", has height 175, has weight 80;
        $l isa limit-double 25;
      """
    Given transaction commits

    Given connection open read transaction for database: typedb
    When get answers of typeql read query
      """
      match
        $p isa person, has name $name, has height $h, has weight $w;
        let $bmi = $w/($h/100 * $h/100);
        $lim isa limit-double;
        $bmi < $lim;
      select
        $name;
      """

    Then uniquely identify answer concepts
      | name            |
      | attr:name:b22.2 |

    When get answers of typeql read query
      """
      match
        $p isa person, has name $name, has height $h, has weight $w;
        let $bmi = $w/($h/100 * $h/100);
        $lim isa limit-double;
        $bmi <= $lim;
      select
        $name;
      """

    Then uniquely identify answer concepts
      | name            |
      | attr:name:b22.2 |
      | attr:name:b25.0 |


  Scenario: Test predicates between thing variables and value variables
    Given connection open write transaction for database: typedb
    Given typeql write query
      """
      insert
        $x isa person, has name "b25.0", has height 160, has weight 64;
        $y isa person, has name "b22.2", has height 180, has weight 72;
        $z isa person, has name "b26.1", has height 175, has weight 80;
        $l isa limit-double 25;
      """
    Given transaction commits

    Given connection open read transaction for database: typedb
    When get answers of typeql read query
      """
      match
        $p isa person, has name $name, has height $h, has weight $w;
        let $bmi = $w/($h/100 * $h/100);
        $lim isa limit-double;
        $lim > $bmi;
      select
        $name;
      """

    Then uniquely identify answer concepts
      | name            |
      | attr:name:b22.2 |

    When get answers of typeql read query
      """
      match
        $p isa person, has name $name, has height $h, has weight $w;
        let $bmi = $w/($h/100 * $h/100);
        $lim isa limit-double;
        $lim >= $bmi;
      select
        $name;
      """

    Then uniquely identify answer concepts
      | name            |
      | attr:name:b22.2 |
      | attr:name:b25.0 |


  Scenario: Division errors are handled
    Given connection open write transaction for database: typedb
    Given typeql write query
      """
      insert
      $n isa name "Baby";
      $a isa age 20;
      $p isa person, has $n, has $a;
      """
    Given transaction commits

    Given connection open read transaction for database: typedb
    Then typeql read query; fails with a message containing: "Division failed"
      """
      match
        $p isa person, has age $a;
        let $div-zero = $a / 0.0; # inf
      """

    Then get answers of typeql read query
      """
      match
        $p isa person, has age $a;
        let $zero = 0.0 / $a ;
      """
    Then answer size is: 1

    When typeql read query; fails with a message containing: "Division failed"
      """
      match let $nan = 0.0 / 0.0; # nan
      """
    Then transaction closes


  Scenario: Test operator precedence
    Given connection open read transaction for database: typedb
    Given get answers of typeql read query
    """
    match
      let $a = 5 * 4 + 3;
      let $b = 3 + 4 * 5;
    """
    Then uniquely identify answer concepts
      | a                | b                |
      | value:integer:23 | value:integer:23 |
    Given get answers of typeql read query
    """
    match
      let $a = 6 * 5 ^ 3 + 2;
      let $b = (6 * (5 ^ 3)) + 2;
    """
    Then uniquely identify answer concepts
      | a                  | b                  |
      | value:double:752.0 | value:double:752.0 |


  Scenario: Operations other than exponentiation are right-associative
    Given connection open read transaction for database: typedb
    Given get answers of typeql read query
    """
    match
      let $a = 6 - 2 - 3;
      let $b = (6 - 2) - 3;
      let $c = 6 - (2 - 3);
    """
    Then uniquely identify answer concepts
      | a               | b               | c               |
      | value:integer:1 | value:integer:1 | value:integer:7 |
    Given get answers of typeql read query
    """
    match
      let $a = 6 / 2 / 3;
      let $b = (6 / 2) / 3;
      let $c = 6 / (2 / 3);
    """
    Then uniquely identify answer concepts
      | a                | b                | c                |
      | value:double:1.0 | value:double:1.0 | value:double:9.0 |
    Given get answers of typeql read query
    """
    match
      let $a = 6 / 2 * 3;
      let $b = (6 / 2) * 3;
      let $c = 6 / (2 * 3);
    """
    Then uniquely identify answer concepts
      | a                | b                | c                |
      | value:double:9.0 | value:double:9.0 | value:double:1.0 |

    Given get answers of typeql read query
    """
    match
      let $a = 5 * 4 % 3 * 2;
      let $b = ((5 * 4) % 3) * 2;
    """
    Then uniquely identify answer concepts
      | a               | b               |
      | value:integer:4 | value:integer:4 |

    # Exponentiation
    Given get answers of typeql read query
    """
    match
      let $a = 2 ^ 2 ^ 2 ^ 2;
      let $b = ((2 ^ 2) ^ 2) ^ 2;
      let $c = 2 ^ (2 ^ (2 ^ 2));
    """
    Then uniquely identify answer concepts
      | a                  | b                | c                  |
      | value:double:65536 | value:double:256 | value:double:65536 |


  Scenario: Test built-in functions accepting concepts
    Given connection open write transaction for database: typedb
    Given typeql write query
    """
    insert $p isa person, has name "Lisa", has age 10, has height 180;
    """
    Given transaction commits

    Given connection open read transaction for database: typedb
    When get answers of typeql read query
    """
      match
        $_ isa $t;
        let $label = label($t);
      select
        $label;
      """
    Then uniquely identify answer concepts
      | label               |
      | value:string:person |
      | value:string:name   |
      | value:string:age    |
      | value:string:height |

    When get answers of typeql read query
    """
    match $x isa $_;
    """
    Then each answer satisfies
    """
    match $x iid <answer.x.iid>; iid($x) == "<answer.x.iid>";
    """


  Scenario: Test role label includes relation namespace
    Given connection open schema transaction for database: typedb
    Given typeql schema query
      """
      define
      relation rel, relates rolename;
      """
    Given transaction commits

    Given connection open read transaction for database: typedb
    When get answers of typeql read query
    """
      match
        $_ relates $r;
        let $label = label($r);
      select
        $label;
      """
    Then uniquely identify answer concepts
      | label                     |
      | value:string:rel:rolename |


  ######################
  # STRING COMPARISONS #
  ######################

  Scenario: String attributes are retrieved correctly when compared with raw values across lengths
    Given connection open schema transaction for database: typedb
    Given typeql schema query
      """
      define
      fun names_helper($len: integer) -> { string }:
        match
          {
            $len > 1;
            let $a_ in names_helper($len - 1);
            let $a = "a" + $a_;
          } or {
            let $a = "a";
          };
        return { $a };
      fun names() -> { string }:
        match let $a in names_helper(20);
        return { $a };
      """
    Given transaction commits

    Given connection open write transaction for database: typedb
    Given typeql write query
    """
      match let $a in names();
      insert $_ isa name == $a;
    """
    Given transaction commits

    Given connection open read transaction for database: typedb
    When get answers of typeql read query
    """
      match $n isa name;
    """
    Then answer size is: 20
    Then uniquely identify answer concepts
      | n                                |
      | attr:name:"a"                    |
      | attr:name:"aa"                   |
      | attr:name:"aaa"                  |
      | attr:name:"aaaa"                 |
      | attr:name:"aaaaa"                |
      | attr:name:"aaaaaa"               |
      | attr:name:"aaaaaaa"              |
      | attr:name:"aaaaaaaa"             |
      | attr:name:"aaaaaaaaa"            |
      | attr:name:"aaaaaaaaaa"           |
      | attr:name:"aaaaaaaaaaa"          |
      | attr:name:"aaaaaaaaaaaa"         |
      | attr:name:"aaaaaaaaaaaaa"        |
      | attr:name:"aaaaaaaaaaaaaa"       |
      | attr:name:"aaaaaaaaaaaaaaa"      |
      | attr:name:"aaaaaaaaaaaaaaaa"     |
      | attr:name:"aaaaaaaaaaaaaaaaa"    |
      | attr:name:"aaaaaaaaaaaaaaaaaa"   |
      | attr:name:"aaaaaaaaaaaaaaaaaaa"  |
      | attr:name:"aaaaaaaaaaaaaaaaaaaa" |

    When get answers of typeql read query
    """
      match
        $n isa name;
        let $n2 in names();
        $n2 > $n;
      reduce $c = count($n2) groupby $n;
    """
    Then answer size is: 19
    Then uniquely identify answer concepts
      | n                               | c                |
      | attr:name:"a"                   | value:integer:19 |
      | attr:name:"aa"                  | value:integer:18 |
      | attr:name:"aaa"                 | value:integer:17 |
      | attr:name:"aaaa"                | value:integer:16 |
      | attr:name:"aaaaa"               | value:integer:15 |
      | attr:name:"aaaaaa"              | value:integer:14 |
      | attr:name:"aaaaaaa"             | value:integer:13 |
      | attr:name:"aaaaaaaa"            | value:integer:12 |
      | attr:name:"aaaaaaaaa"           | value:integer:11 |
      | attr:name:"aaaaaaaaaa"          | value:integer:10 |
      | attr:name:"aaaaaaaaaaa"         | value:integer:9  |
      | attr:name:"aaaaaaaaaaaa"        | value:integer:8  |
      | attr:name:"aaaaaaaaaaaaa"       | value:integer:7  |
      | attr:name:"aaaaaaaaaaaaaa"      | value:integer:6  |
      | attr:name:"aaaaaaaaaaaaaaa"     | value:integer:5  |
      | attr:name:"aaaaaaaaaaaaaaaa"    | value:integer:4  |
      | attr:name:"aaaaaaaaaaaaaaaaa"   | value:integer:3  |
      | attr:name:"aaaaaaaaaaaaaaaaaa"  | value:integer:2  |
      | attr:name:"aaaaaaaaaaaaaaaaaaa" | value:integer:1  |

    When get answers of typeql read query
    """
      match
        $n isa name;
        let $n2 in names();
        $n2 >= $n;
      reduce $c = count($n2) groupby $n;
    """
    Then answer size is: 20
    Then uniquely identify answer concepts
      | n                                | c                |
      | attr:name:"a"                    | value:integer:20 |
      | attr:name:"aa"                   | value:integer:19 |
      | attr:name:"aaa"                  | value:integer:18 |
      | attr:name:"aaaa"                 | value:integer:17 |
      | attr:name:"aaaaa"                | value:integer:16 |
      | attr:name:"aaaaaa"               | value:integer:15 |
      | attr:name:"aaaaaaa"              | value:integer:14 |
      | attr:name:"aaaaaaaa"             | value:integer:13 |
      | attr:name:"aaaaaaaaa"            | value:integer:12 |
      | attr:name:"aaaaaaaaaa"           | value:integer:11 |
      | attr:name:"aaaaaaaaaaa"          | value:integer:10 |
      | attr:name:"aaaaaaaaaaaa"         | value:integer:9  |
      | attr:name:"aaaaaaaaaaaaa"        | value:integer:8  |
      | attr:name:"aaaaaaaaaaaaaa"       | value:integer:7  |
      | attr:name:"aaaaaaaaaaaaaaa"      | value:integer:6  |
      | attr:name:"aaaaaaaaaaaaaaaa"     | value:integer:5  |
      | attr:name:"aaaaaaaaaaaaaaaaa"    | value:integer:4  |
      | attr:name:"aaaaaaaaaaaaaaaaaa"   | value:integer:3  |
      | attr:name:"aaaaaaaaaaaaaaaaaaa"  | value:integer:2  |
      | attr:name:"aaaaaaaaaaaaaaaaaaaa" | value:integer:1  |

    When get answers of typeql read query
    """
      match
        $n isa name;
        let $n2 in names();
        $n2 < $n;
      reduce $c = count($n2) groupby $n;
    """
    Then answer size is: 19
    Then uniquely identify answer concepts
      | n                                | c                |
      | attr:name:"aa"                   | value:integer:1  |
      | attr:name:"aaa"                  | value:integer:2  |
      | attr:name:"aaaa"                 | value:integer:3  |
      | attr:name:"aaaaa"                | value:integer:4  |
      | attr:name:"aaaaaa"               | value:integer:5  |
      | attr:name:"aaaaaaa"              | value:integer:6  |
      | attr:name:"aaaaaaaa"             | value:integer:7  |
      | attr:name:"aaaaaaaaa"            | value:integer:8  |
      | attr:name:"aaaaaaaaaa"           | value:integer:9  |
      | attr:name:"aaaaaaaaaaa"          | value:integer:10 |
      | attr:name:"aaaaaaaaaaaa"         | value:integer:11 |
      | attr:name:"aaaaaaaaaaaaa"        | value:integer:12 |
      | attr:name:"aaaaaaaaaaaaaa"       | value:integer:13 |
      | attr:name:"aaaaaaaaaaaaaaa"      | value:integer:14 |
      | attr:name:"aaaaaaaaaaaaaaaa"     | value:integer:15 |
      | attr:name:"aaaaaaaaaaaaaaaaa"    | value:integer:16 |
      | attr:name:"aaaaaaaaaaaaaaaaaa"   | value:integer:17 |
      | attr:name:"aaaaaaaaaaaaaaaaaaa"  | value:integer:18 |
      | attr:name:"aaaaaaaaaaaaaaaaaaaa" | value:integer:19 |

    When get answers of typeql read query
    """
      match
        $n isa name;
        let $n2 in names();
        $n2 <= $n;
      reduce $c = count($n2) groupby $n;
    """
    Then answer size is: 20
    Then uniquely identify answer concepts
      | n                                | c                |
      | attr:name:"a"                    | value:integer:1  |
      | attr:name:"aa"                   | value:integer:2  |
      | attr:name:"aaa"                  | value:integer:3  |
      | attr:name:"aaaa"                 | value:integer:4  |
      | attr:name:"aaaaa"                | value:integer:5  |
      | attr:name:"aaaaaa"               | value:integer:6  |
      | attr:name:"aaaaaaa"              | value:integer:7  |
      | attr:name:"aaaaaaaa"             | value:integer:8  |
      | attr:name:"aaaaaaaaa"            | value:integer:9  |
      | attr:name:"aaaaaaaaaa"           | value:integer:10 |
      | attr:name:"aaaaaaaaaaa"          | value:integer:11 |
      | attr:name:"aaaaaaaaaaaa"         | value:integer:12 |
      | attr:name:"aaaaaaaaaaaaa"        | value:integer:13 |
      | attr:name:"aaaaaaaaaaaaaa"       | value:integer:14 |
      | attr:name:"aaaaaaaaaaaaaaa"      | value:integer:15 |
      | attr:name:"aaaaaaaaaaaaaaaa"     | value:integer:16 |
      | attr:name:"aaaaaaaaaaaaaaaaa"    | value:integer:17 |
      | attr:name:"aaaaaaaaaaaaaaaaaa"   | value:integer:18 |
      | attr:name:"aaaaaaaaaaaaaaaaaaa"  | value:integer:19 |
      | attr:name:"aaaaaaaaaaaaaaaaaaaa" | value:integer:20 |

    When get answers of typeql read query
    """
      match
        $n isa name;
        let $n2 in names();
        $n2 != $n;
      reduce $c = count($n2) groupby $n;
    """
    Then answer size is: 20
    Then uniquely identify answer concepts
      | n                                | c                |
      | attr:name:"a"                    | value:integer:19 |
      | attr:name:"aa"                   | value:integer:19 |
      | attr:name:"aaa"                  | value:integer:19 |
      | attr:name:"aaaa"                 | value:integer:19 |
      | attr:name:"aaaaa"                | value:integer:19 |
      | attr:name:"aaaaaa"               | value:integer:19 |
      | attr:name:"aaaaaaa"              | value:integer:19 |
      | attr:name:"aaaaaaaa"             | value:integer:19 |
      | attr:name:"aaaaaaaaa"            | value:integer:19 |
      | attr:name:"aaaaaaaaaa"           | value:integer:19 |
      | attr:name:"aaaaaaaaaaa"          | value:integer:19 |
      | attr:name:"aaaaaaaaaaaa"         | value:integer:19 |
      | attr:name:"aaaaaaaaaaaaa"        | value:integer:19 |
      | attr:name:"aaaaaaaaaaaaaa"       | value:integer:19 |
      | attr:name:"aaaaaaaaaaaaaaa"      | value:integer:19 |
      | attr:name:"aaaaaaaaaaaaaaaa"     | value:integer:19 |
      | attr:name:"aaaaaaaaaaaaaaaaa"    | value:integer:19 |
      | attr:name:"aaaaaaaaaaaaaaaaaa"   | value:integer:19 |
      | attr:name:"aaaaaaaaaaaaaaaaaaa"  | value:integer:19 |
      | attr:name:"aaaaaaaaaaaaaaaaaaaa" | value:integer:19 |

    When get answers of typeql read query
    """
      match
        $n isa name;
        let $n2 in names();
        $n2 == $n;
      reduce $c = count($n2) groupby $n;
    """
    Then answer size is: 20
    Then uniquely identify answer concepts
      | n                                | c               |
      | attr:name:"a"                    | value:integer:1 |
      | attr:name:"aa"                   | value:integer:1 |
      | attr:name:"aaa"                  | value:integer:1 |
      | attr:name:"aaaa"                 | value:integer:1 |
      | attr:name:"aaaaa"                | value:integer:1 |
      | attr:name:"aaaaaa"               | value:integer:1 |
      | attr:name:"aaaaaaa"              | value:integer:1 |
      | attr:name:"aaaaaaaa"             | value:integer:1 |
      | attr:name:"aaaaaaaaa"            | value:integer:1 |
      | attr:name:"aaaaaaaaaa"           | value:integer:1 |
      | attr:name:"aaaaaaaaaaa"          | value:integer:1 |
      | attr:name:"aaaaaaaaaaaa"         | value:integer:1 |
      | attr:name:"aaaaaaaaaaaaa"        | value:integer:1 |
      | attr:name:"aaaaaaaaaaaaaa"       | value:integer:1 |
      | attr:name:"aaaaaaaaaaaaaaa"      | value:integer:1 |
      | attr:name:"aaaaaaaaaaaaaaaa"     | value:integer:1 |
      | attr:name:"aaaaaaaaaaaaaaaaa"    | value:integer:1 |
      | attr:name:"aaaaaaaaaaaaaaaaaa"   | value:integer:1 |
      | attr:name:"aaaaaaaaaaaaaaaaaaa"  | value:integer:1 |
      | attr:name:"aaaaaaaaaaaaaaaaaaaa" | value:integer:1 |


  Scenario: String attributes are retrieved correctly when compared with other attributes across lengths
    Given connection open schema transaction for database: typedb
    Given typeql schema query
      """
      define
      fun names_helper($len: integer) -> { string }:
        match
          {
            $len > 1;
            let $a_ in names_helper($len - 1);
            let $a = "a" + $a_;
          } or {
            let $a = "a";
          };
        return { $a };
      fun names() -> { string }:
        match let $a in names_helper(20);
        return { $a };
      """
    Given transaction commits

    Given connection open write transaction for database: typedb
    Given typeql write query
    """
      match let $a in names();
      insert $_ isa name == $a;
    """
    Given transaction commits

    Given connection open read transaction for database: typedb
    When get answers of typeql read query
    """
      match $n isa name;
    """
    Then answer size is: 20
    Then uniquely identify answer concepts
      | n                                |
      | attr:name:"a"                    |
      | attr:name:"aa"                   |
      | attr:name:"aaa"                  |
      | attr:name:"aaaa"                 |
      | attr:name:"aaaaa"                |
      | attr:name:"aaaaaa"               |
      | attr:name:"aaaaaaa"              |
      | attr:name:"aaaaaaaa"             |
      | attr:name:"aaaaaaaaa"            |
      | attr:name:"aaaaaaaaaa"           |
      | attr:name:"aaaaaaaaaaa"          |
      | attr:name:"aaaaaaaaaaaa"         |
      | attr:name:"aaaaaaaaaaaaa"        |
      | attr:name:"aaaaaaaaaaaaaa"       |
      | attr:name:"aaaaaaaaaaaaaaa"      |
      | attr:name:"aaaaaaaaaaaaaaaa"     |
      | attr:name:"aaaaaaaaaaaaaaaaa"    |
      | attr:name:"aaaaaaaaaaaaaaaaaa"   |
      | attr:name:"aaaaaaaaaaaaaaaaaaa"  |
      | attr:name:"aaaaaaaaaaaaaaaaaaaa" |

    When get answers of typeql read query
    """
      match
        $n isa name;
        $n2 isa name;
        $n2 > $n;
      reduce $c = count($n2) groupby $n;
    """
    Then answer size is: 19
    Then uniquely identify answer concepts
      | n                               | c                |
      | attr:name:"a"                   | value:integer:19 |
      | attr:name:"aa"                  | value:integer:18 |
      | attr:name:"aaa"                 | value:integer:17 |
      | attr:name:"aaaa"                | value:integer:16 |
      | attr:name:"aaaaa"               | value:integer:15 |
      | attr:name:"aaaaaa"              | value:integer:14 |
      | attr:name:"aaaaaaa"             | value:integer:13 |
      | attr:name:"aaaaaaaa"            | value:integer:12 |
      | attr:name:"aaaaaaaaa"           | value:integer:11 |
      | attr:name:"aaaaaaaaaa"          | value:integer:10 |
      | attr:name:"aaaaaaaaaaa"         | value:integer:9  |
      | attr:name:"aaaaaaaaaaaa"        | value:integer:8  |
      | attr:name:"aaaaaaaaaaaaa"       | value:integer:7  |
      | attr:name:"aaaaaaaaaaaaaa"      | value:integer:6  |
      | attr:name:"aaaaaaaaaaaaaaa"     | value:integer:5  |
      | attr:name:"aaaaaaaaaaaaaaaa"    | value:integer:4  |
      | attr:name:"aaaaaaaaaaaaaaaaa"   | value:integer:3  |
      | attr:name:"aaaaaaaaaaaaaaaaaa"  | value:integer:2  |
      | attr:name:"aaaaaaaaaaaaaaaaaaa" | value:integer:1  |

    When get answers of typeql read query
    """
      match
        $n isa name;
        $n2 isa name;
        $n2 >= $n;
      reduce $c = count($n2) groupby $n;
    """
    Then answer size is: 20
    Then uniquely identify answer concepts
      | n                                | c                |
      | attr:name:"a"                    | value:integer:20 |
      | attr:name:"aa"                   | value:integer:19 |
      | attr:name:"aaa"                  | value:integer:18 |
      | attr:name:"aaaa"                 | value:integer:17 |
      | attr:name:"aaaaa"                | value:integer:16 |
      | attr:name:"aaaaaa"               | value:integer:15 |
      | attr:name:"aaaaaaa"              | value:integer:14 |
      | attr:name:"aaaaaaaa"             | value:integer:13 |
      | attr:name:"aaaaaaaaa"            | value:integer:12 |
      | attr:name:"aaaaaaaaaa"           | value:integer:11 |
      | attr:name:"aaaaaaaaaaa"          | value:integer:10 |
      | attr:name:"aaaaaaaaaaaa"         | value:integer:9  |
      | attr:name:"aaaaaaaaaaaaa"        | value:integer:8  |
      | attr:name:"aaaaaaaaaaaaaa"       | value:integer:7  |
      | attr:name:"aaaaaaaaaaaaaaa"      | value:integer:6  |
      | attr:name:"aaaaaaaaaaaaaaaa"     | value:integer:5  |
      | attr:name:"aaaaaaaaaaaaaaaaa"    | value:integer:4  |
      | attr:name:"aaaaaaaaaaaaaaaaaa"   | value:integer:3  |
      | attr:name:"aaaaaaaaaaaaaaaaaaa"  | value:integer:2  |
      | attr:name:"aaaaaaaaaaaaaaaaaaaa" | value:integer:1  |

    When get answers of typeql read query
    """
      match
        $n isa name;
        $n2 isa name;
        $n2 < $n;
      reduce $c = count($n2) groupby $n;
    """
    Then answer size is: 19
    Then uniquely identify answer concepts
      | n                                | c                |
      | attr:name:"aa"                   | value:integer:1  |
      | attr:name:"aaa"                  | value:integer:2  |
      | attr:name:"aaaa"                 | value:integer:3  |
      | attr:name:"aaaaa"                | value:integer:4  |
      | attr:name:"aaaaaa"               | value:integer:5  |
      | attr:name:"aaaaaaa"              | value:integer:6  |
      | attr:name:"aaaaaaaa"             | value:integer:7  |
      | attr:name:"aaaaaaaaa"            | value:integer:8  |
      | attr:name:"aaaaaaaaaa"           | value:integer:9  |
      | attr:name:"aaaaaaaaaaa"          | value:integer:10 |
      | attr:name:"aaaaaaaaaaaa"         | value:integer:11 |
      | attr:name:"aaaaaaaaaaaaa"        | value:integer:12 |
      | attr:name:"aaaaaaaaaaaaaa"       | value:integer:13 |
      | attr:name:"aaaaaaaaaaaaaaa"      | value:integer:14 |
      | attr:name:"aaaaaaaaaaaaaaaa"     | value:integer:15 |
      | attr:name:"aaaaaaaaaaaaaaaaa"    | value:integer:16 |
      | attr:name:"aaaaaaaaaaaaaaaaaa"   | value:integer:17 |
      | attr:name:"aaaaaaaaaaaaaaaaaaa"  | value:integer:18 |
      | attr:name:"aaaaaaaaaaaaaaaaaaaa" | value:integer:19 |

    When get answers of typeql read query
    """
      match
        $n isa name;
        $n2 isa name;
        $n2 <= $n;
      reduce $c = count($n2) groupby $n;
    """
    Then answer size is: 20
    Then uniquely identify answer concepts
      | n                                | c                |
      | attr:name:"a"                    | value:integer:1  |
      | attr:name:"aa"                   | value:integer:2  |
      | attr:name:"aaa"                  | value:integer:3  |
      | attr:name:"aaaa"                 | value:integer:4  |
      | attr:name:"aaaaa"                | value:integer:5  |
      | attr:name:"aaaaaa"               | value:integer:6  |
      | attr:name:"aaaaaaa"              | value:integer:7  |
      | attr:name:"aaaaaaaa"             | value:integer:8  |
      | attr:name:"aaaaaaaaa"            | value:integer:9  |
      | attr:name:"aaaaaaaaaa"           | value:integer:10 |
      | attr:name:"aaaaaaaaaaa"          | value:integer:11 |
      | attr:name:"aaaaaaaaaaaa"         | value:integer:12 |
      | attr:name:"aaaaaaaaaaaaa"        | value:integer:13 |
      | attr:name:"aaaaaaaaaaaaaa"       | value:integer:14 |
      | attr:name:"aaaaaaaaaaaaaaa"      | value:integer:15 |
      | attr:name:"aaaaaaaaaaaaaaaa"     | value:integer:16 |
      | attr:name:"aaaaaaaaaaaaaaaaa"    | value:integer:17 |
      | attr:name:"aaaaaaaaaaaaaaaaaa"   | value:integer:18 |
      | attr:name:"aaaaaaaaaaaaaaaaaaa"  | value:integer:19 |
      | attr:name:"aaaaaaaaaaaaaaaaaaaa" | value:integer:20 |

    When get answers of typeql read query
    """
      match
        $n isa name;
        $n2 isa name;
        $n2 != $n;
      reduce $c = count($n2) groupby $n;
    """
    Then answer size is: 20
    Then uniquely identify answer concepts
      | n                                | c                |
      | attr:name:"a"                    | value:integer:19 |
      | attr:name:"aa"                   | value:integer:19 |
      | attr:name:"aaa"                  | value:integer:19 |
      | attr:name:"aaaa"                 | value:integer:19 |
      | attr:name:"aaaaa"                | value:integer:19 |
      | attr:name:"aaaaaa"               | value:integer:19 |
      | attr:name:"aaaaaaa"              | value:integer:19 |
      | attr:name:"aaaaaaaa"             | value:integer:19 |
      | attr:name:"aaaaaaaaa"            | value:integer:19 |
      | attr:name:"aaaaaaaaaa"           | value:integer:19 |
      | attr:name:"aaaaaaaaaaa"          | value:integer:19 |
      | attr:name:"aaaaaaaaaaaa"         | value:integer:19 |
      | attr:name:"aaaaaaaaaaaaa"        | value:integer:19 |
      | attr:name:"aaaaaaaaaaaaaa"       | value:integer:19 |
      | attr:name:"aaaaaaaaaaaaaaa"      | value:integer:19 |
      | attr:name:"aaaaaaaaaaaaaaaa"     | value:integer:19 |
      | attr:name:"aaaaaaaaaaaaaaaaa"    | value:integer:19 |
      | attr:name:"aaaaaaaaaaaaaaaaaa"   | value:integer:19 |
      | attr:name:"aaaaaaaaaaaaaaaaaaa"  | value:integer:19 |
      | attr:name:"aaaaaaaaaaaaaaaaaaaa" | value:integer:19 |

    When get answers of typeql read query
    """
      match
        $n isa name;
        $n2 isa name;
        $n2 == $n;
      reduce $c = count($n2) groupby $n;
    """
    Then answer size is: 20
    Then uniquely identify answer concepts
      | n                                | c               |
      | attr:name:"a"                    | value:integer:1 |
      | attr:name:"aa"                   | value:integer:1 |
      | attr:name:"aaa"                  | value:integer:1 |
      | attr:name:"aaaa"                 | value:integer:1 |
      | attr:name:"aaaaa"                | value:integer:1 |
      | attr:name:"aaaaaa"               | value:integer:1 |
      | attr:name:"aaaaaaa"              | value:integer:1 |
      | attr:name:"aaaaaaaa"             | value:integer:1 |
      | attr:name:"aaaaaaaaa"            | value:integer:1 |
      | attr:name:"aaaaaaaaaa"           | value:integer:1 |
      | attr:name:"aaaaaaaaaaa"          | value:integer:1 |
      | attr:name:"aaaaaaaaaaaa"         | value:integer:1 |
      | attr:name:"aaaaaaaaaaaaa"        | value:integer:1 |
      | attr:name:"aaaaaaaaaaaaaa"       | value:integer:1 |
      | attr:name:"aaaaaaaaaaaaaaa"      | value:integer:1 |
      | attr:name:"aaaaaaaaaaaaaaaa"     | value:integer:1 |
      | attr:name:"aaaaaaaaaaaaaaaaa"    | value:integer:1 |
      | attr:name:"aaaaaaaaaaaaaaaaaa"   | value:integer:1 |
      | attr:name:"aaaaaaaaaaaaaaaaaaa"  | value:integer:1 |
      | attr:name:"aaaaaaaaaaaaaaaaaaaa" | value:integer:1 |


  Scenario: Owned string attributes are retrieved correctly when compared with raw values across lengths
    Given connection open schema transaction for database: typedb
    Given typeql schema query
      """
      define
      fun names_helper($len: integer) -> { string }:
        match
          {
            $len > 1;
            let $a_ in names_helper($len - 1);
            let $a = "a" + $a_;
          } or {
            let $a = "a";
          };
        return { $a };
      fun names() -> { string }:
        match let $a in names_helper(20);
        return { $a };
      """
    Given transaction commits

    Given connection open write transaction for database: typedb
    Given typeql write query
    """
      match let $a in names();
      insert $_ isa person, has name == $a;
    """
    Given transaction commits

    Given connection open read transaction for database: typedb
    When get answers of typeql read query
    """
      match $_ has name $n;
    """
    Then answer size is: 20
    Then uniquely identify answer concepts
      | n                                |
      | attr:name:"a"                    |
      | attr:name:"aa"                   |
      | attr:name:"aaa"                  |
      | attr:name:"aaaa"                 |
      | attr:name:"aaaaa"                |
      | attr:name:"aaaaaa"               |
      | attr:name:"aaaaaaa"              |
      | attr:name:"aaaaaaaa"             |
      | attr:name:"aaaaaaaaa"            |
      | attr:name:"aaaaaaaaaa"           |
      | attr:name:"aaaaaaaaaaa"          |
      | attr:name:"aaaaaaaaaaaa"         |
      | attr:name:"aaaaaaaaaaaaa"        |
      | attr:name:"aaaaaaaaaaaaaa"       |
      | attr:name:"aaaaaaaaaaaaaaa"      |
      | attr:name:"aaaaaaaaaaaaaaaa"     |
      | attr:name:"aaaaaaaaaaaaaaaaa"    |
      | attr:name:"aaaaaaaaaaaaaaaaaa"   |
      | attr:name:"aaaaaaaaaaaaaaaaaaa"  |
      | attr:name:"aaaaaaaaaaaaaaaaaaaa" |

    When get answers of typeql read query
    """
      match
        $_ has name $n;
        let $n2 in names();
        $n2 > $n;
      reduce $c = count($n2) groupby $n;
    """
    Then answer size is: 19
    Then uniquely identify answer concepts
      | n                               | c                |
      | attr:name:"a"                   | value:integer:19 |
      | attr:name:"aa"                  | value:integer:18 |
      | attr:name:"aaa"                 | value:integer:17 |
      | attr:name:"aaaa"                | value:integer:16 |
      | attr:name:"aaaaa"               | value:integer:15 |
      | attr:name:"aaaaaa"              | value:integer:14 |
      | attr:name:"aaaaaaa"             | value:integer:13 |
      | attr:name:"aaaaaaaa"            | value:integer:12 |
      | attr:name:"aaaaaaaaa"           | value:integer:11 |
      | attr:name:"aaaaaaaaaa"          | value:integer:10 |
      | attr:name:"aaaaaaaaaaa"         | value:integer:9  |
      | attr:name:"aaaaaaaaaaaa"        | value:integer:8  |
      | attr:name:"aaaaaaaaaaaaa"       | value:integer:7  |
      | attr:name:"aaaaaaaaaaaaaa"      | value:integer:6  |
      | attr:name:"aaaaaaaaaaaaaaa"     | value:integer:5  |
      | attr:name:"aaaaaaaaaaaaaaaa"    | value:integer:4  |
      | attr:name:"aaaaaaaaaaaaaaaaa"   | value:integer:3  |
      | attr:name:"aaaaaaaaaaaaaaaaaa"  | value:integer:2  |
      | attr:name:"aaaaaaaaaaaaaaaaaaa" | value:integer:1  |

    When get answers of typeql read query
    """
      match
        $_ has name $n;
        let $n2 in names();
        $n2 >= $n;
      reduce $c = count($n2) groupby $n;
    """
    Then answer size is: 20
    Then uniquely identify answer concepts
      | n                                | c                |
      | attr:name:"a"                    | value:integer:20 |
      | attr:name:"aa"                   | value:integer:19 |
      | attr:name:"aaa"                  | value:integer:18 |
      | attr:name:"aaaa"                 | value:integer:17 |
      | attr:name:"aaaaa"                | value:integer:16 |
      | attr:name:"aaaaaa"               | value:integer:15 |
      | attr:name:"aaaaaaa"              | value:integer:14 |
      | attr:name:"aaaaaaaa"             | value:integer:13 |
      | attr:name:"aaaaaaaaa"            | value:integer:12 |
      | attr:name:"aaaaaaaaaa"           | value:integer:11 |
      | attr:name:"aaaaaaaaaaa"          | value:integer:10 |
      | attr:name:"aaaaaaaaaaaa"         | value:integer:9  |
      | attr:name:"aaaaaaaaaaaaa"        | value:integer:8  |
      | attr:name:"aaaaaaaaaaaaaa"       | value:integer:7  |
      | attr:name:"aaaaaaaaaaaaaaa"      | value:integer:6  |
      | attr:name:"aaaaaaaaaaaaaaaa"     | value:integer:5  |
      | attr:name:"aaaaaaaaaaaaaaaaa"    | value:integer:4  |
      | attr:name:"aaaaaaaaaaaaaaaaaa"   | value:integer:3  |
      | attr:name:"aaaaaaaaaaaaaaaaaaa"  | value:integer:2  |
      | attr:name:"aaaaaaaaaaaaaaaaaaaa" | value:integer:1  |

    When get answers of typeql read query
    """
      match
        $_ has name $n;
        let $n2 in names();
        $n2 < $n;
      reduce $c = count($n2) groupby $n;
    """
    Then answer size is: 19
    Then uniquely identify answer concepts
      | n                                | c                |
      | attr:name:"aa"                   | value:integer:1  |
      | attr:name:"aaa"                  | value:integer:2  |
      | attr:name:"aaaa"                 | value:integer:3  |
      | attr:name:"aaaaa"                | value:integer:4  |
      | attr:name:"aaaaaa"               | value:integer:5  |
      | attr:name:"aaaaaaa"              | value:integer:6  |
      | attr:name:"aaaaaaaa"             | value:integer:7  |
      | attr:name:"aaaaaaaaa"            | value:integer:8  |
      | attr:name:"aaaaaaaaaa"           | value:integer:9  |
      | attr:name:"aaaaaaaaaaa"          | value:integer:10 |
      | attr:name:"aaaaaaaaaaaa"         | value:integer:11 |
      | attr:name:"aaaaaaaaaaaaa"        | value:integer:12 |
      | attr:name:"aaaaaaaaaaaaaa"       | value:integer:13 |
      | attr:name:"aaaaaaaaaaaaaaa"      | value:integer:14 |
      | attr:name:"aaaaaaaaaaaaaaaa"     | value:integer:15 |
      | attr:name:"aaaaaaaaaaaaaaaaa"    | value:integer:16 |
      | attr:name:"aaaaaaaaaaaaaaaaaa"   | value:integer:17 |
      | attr:name:"aaaaaaaaaaaaaaaaaaa"  | value:integer:18 |
      | attr:name:"aaaaaaaaaaaaaaaaaaaa" | value:integer:19 |

    When get answers of typeql read query
    """
      match
        $_ has name $n;
        let $n2 in names();
        $n2 <= $n;
      reduce $c = count($n2) groupby $n;
    """
    Then answer size is: 20
    Then uniquely identify answer concepts
      | n                                | c                |
      | attr:name:"a"                    | value:integer:1  |
      | attr:name:"aa"                   | value:integer:2  |
      | attr:name:"aaa"                  | value:integer:3  |
      | attr:name:"aaaa"                 | value:integer:4  |
      | attr:name:"aaaaa"                | value:integer:5  |
      | attr:name:"aaaaaa"               | value:integer:6  |
      | attr:name:"aaaaaaa"              | value:integer:7  |
      | attr:name:"aaaaaaaa"             | value:integer:8  |
      | attr:name:"aaaaaaaaa"            | value:integer:9  |
      | attr:name:"aaaaaaaaaa"           | value:integer:10 |
      | attr:name:"aaaaaaaaaaa"          | value:integer:11 |
      | attr:name:"aaaaaaaaaaaa"         | value:integer:12 |
      | attr:name:"aaaaaaaaaaaaa"        | value:integer:13 |
      | attr:name:"aaaaaaaaaaaaaa"       | value:integer:14 |
      | attr:name:"aaaaaaaaaaaaaaa"      | value:integer:15 |
      | attr:name:"aaaaaaaaaaaaaaaa"     | value:integer:16 |
      | attr:name:"aaaaaaaaaaaaaaaaa"    | value:integer:17 |
      | attr:name:"aaaaaaaaaaaaaaaaaa"   | value:integer:18 |
      | attr:name:"aaaaaaaaaaaaaaaaaaa"  | value:integer:19 |
      | attr:name:"aaaaaaaaaaaaaaaaaaaa" | value:integer:20 |

    When get answers of typeql read query
    """
      match
        $_ has name $n;
        let $n2 in names();
        $n2 != $n;
      reduce $c = count($n2) groupby $n;
    """
    Then answer size is: 20
    Then uniquely identify answer concepts
      | n                                | c                |
      | attr:name:"a"                    | value:integer:19 |
      | attr:name:"aa"                   | value:integer:19 |
      | attr:name:"aaa"                  | value:integer:19 |
      | attr:name:"aaaa"                 | value:integer:19 |
      | attr:name:"aaaaa"                | value:integer:19 |
      | attr:name:"aaaaaa"               | value:integer:19 |
      | attr:name:"aaaaaaa"              | value:integer:19 |
      | attr:name:"aaaaaaaa"             | value:integer:19 |
      | attr:name:"aaaaaaaaa"            | value:integer:19 |
      | attr:name:"aaaaaaaaaa"           | value:integer:19 |
      | attr:name:"aaaaaaaaaaa"          | value:integer:19 |
      | attr:name:"aaaaaaaaaaaa"         | value:integer:19 |
      | attr:name:"aaaaaaaaaaaaa"        | value:integer:19 |
      | attr:name:"aaaaaaaaaaaaaa"       | value:integer:19 |
      | attr:name:"aaaaaaaaaaaaaaa"      | value:integer:19 |
      | attr:name:"aaaaaaaaaaaaaaaa"     | value:integer:19 |
      | attr:name:"aaaaaaaaaaaaaaaaa"    | value:integer:19 |
      | attr:name:"aaaaaaaaaaaaaaaaaa"   | value:integer:19 |
      | attr:name:"aaaaaaaaaaaaaaaaaaa"  | value:integer:19 |
      | attr:name:"aaaaaaaaaaaaaaaaaaaa" | value:integer:19 |

    When get answers of typeql read query
    """
      match
        $_ has name $n;
        let $n2 in names();
        $n2 == $n;
      reduce $c = count($n2) groupby $n;
    """
    Then answer size is: 20
    Then uniquely identify answer concepts
      | n                                | c               |
      | attr:name:"a"                    | value:integer:1 |
      | attr:name:"aa"                   | value:integer:1 |
      | attr:name:"aaa"                  | value:integer:1 |
      | attr:name:"aaaa"                 | value:integer:1 |
      | attr:name:"aaaaa"                | value:integer:1 |
      | attr:name:"aaaaaa"               | value:integer:1 |
      | attr:name:"aaaaaaa"              | value:integer:1 |
      | attr:name:"aaaaaaaa"             | value:integer:1 |
      | attr:name:"aaaaaaaaa"            | value:integer:1 |
      | attr:name:"aaaaaaaaaa"           | value:integer:1 |
      | attr:name:"aaaaaaaaaaa"          | value:integer:1 |
      | attr:name:"aaaaaaaaaaaa"         | value:integer:1 |
      | attr:name:"aaaaaaaaaaaaa"        | value:integer:1 |
      | attr:name:"aaaaaaaaaaaaaa"       | value:integer:1 |
      | attr:name:"aaaaaaaaaaaaaaa"      | value:integer:1 |
      | attr:name:"aaaaaaaaaaaaaaaa"     | value:integer:1 |
      | attr:name:"aaaaaaaaaaaaaaaaa"    | value:integer:1 |
      | attr:name:"aaaaaaaaaaaaaaaaaa"   | value:integer:1 |
      | attr:name:"aaaaaaaaaaaaaaaaaaa"  | value:integer:1 |
      | attr:name:"aaaaaaaaaaaaaaaaaaaa" | value:integer:1 |


  Scenario: Owned string attributes are retrieved correctly when compared with other attributes across lengths
    Given connection open schema transaction for database: typedb
    Given typeql schema query
      """
      define
      fun names_helper($len: integer) -> { string }:
        match
          {
            $len > 1;
            let $a_ in names_helper($len - 1);
            let $a = "a" + $a_;
          } or {
            let $a = "a";
          };
        return { $a };
      fun names() -> { string }:
        match let $a in names_helper(20);
        return { $a };
      """
    Given transaction commits

    Given connection open write transaction for database: typedb
    Given typeql write query
    """
      match let $a in names();
      insert $_ isa person, has name == $a;
    """
    Given transaction commits

    Given connection open read transaction for database: typedb
    When get answers of typeql read query
    """
      match $_ has name $n;
    """
    Then answer size is: 20
    Then uniquely identify answer concepts
      | n                                |
      | attr:name:"a"                    |
      | attr:name:"aa"                   |
      | attr:name:"aaa"                  |
      | attr:name:"aaaa"                 |
      | attr:name:"aaaaa"                |
      | attr:name:"aaaaaa"               |
      | attr:name:"aaaaaaa"              |
      | attr:name:"aaaaaaaa"             |
      | attr:name:"aaaaaaaaa"            |
      | attr:name:"aaaaaaaaaa"           |
      | attr:name:"aaaaaaaaaaa"          |
      | attr:name:"aaaaaaaaaaaa"         |
      | attr:name:"aaaaaaaaaaaaa"        |
      | attr:name:"aaaaaaaaaaaaaa"       |
      | attr:name:"aaaaaaaaaaaaaaa"      |
      | attr:name:"aaaaaaaaaaaaaaaa"     |
      | attr:name:"aaaaaaaaaaaaaaaaa"    |
      | attr:name:"aaaaaaaaaaaaaaaaaa"   |
      | attr:name:"aaaaaaaaaaaaaaaaaaa"  |
      | attr:name:"aaaaaaaaaaaaaaaaaaaa" |

    When get answers of typeql read query
    """
      match
        $_ has name $n;
        $_ has name $n2;
        $n2 > $n;
      reduce $c = count($n2) groupby $n;
    """
    Then answer size is: 19
    Then uniquely identify answer concepts
      | n                               | c                |
      | attr:name:"a"                   | value:integer:19 |
      | attr:name:"aa"                  | value:integer:18 |
      | attr:name:"aaa"                 | value:integer:17 |
      | attr:name:"aaaa"                | value:integer:16 |
      | attr:name:"aaaaa"               | value:integer:15 |
      | attr:name:"aaaaaa"              | value:integer:14 |
      | attr:name:"aaaaaaa"             | value:integer:13 |
      | attr:name:"aaaaaaaa"            | value:integer:12 |
      | attr:name:"aaaaaaaaa"           | value:integer:11 |
      | attr:name:"aaaaaaaaaa"          | value:integer:10 |
      | attr:name:"aaaaaaaaaaa"         | value:integer:9  |
      | attr:name:"aaaaaaaaaaaa"        | value:integer:8  |
      | attr:name:"aaaaaaaaaaaaa"       | value:integer:7  |
      | attr:name:"aaaaaaaaaaaaaa"      | value:integer:6  |
      | attr:name:"aaaaaaaaaaaaaaa"     | value:integer:5  |
      | attr:name:"aaaaaaaaaaaaaaaa"    | value:integer:4  |
      | attr:name:"aaaaaaaaaaaaaaaaa"   | value:integer:3  |
      | attr:name:"aaaaaaaaaaaaaaaaaa"  | value:integer:2  |
      | attr:name:"aaaaaaaaaaaaaaaaaaa" | value:integer:1  |

    When get answers of typeql read query
    """
      match
        $_ has name $n;
        $_ has name $n2;
        $n2 >= $n;
      reduce $c = count($n2) groupby $n;
    """
    Then answer size is: 20
    Then uniquely identify answer concepts
      | n                                | c                |
      | attr:name:"a"                    | value:integer:20 |
      | attr:name:"aa"                   | value:integer:19 |
      | attr:name:"aaa"                  | value:integer:18 |
      | attr:name:"aaaa"                 | value:integer:17 |
      | attr:name:"aaaaa"                | value:integer:16 |
      | attr:name:"aaaaaa"               | value:integer:15 |
      | attr:name:"aaaaaaa"              | value:integer:14 |
      | attr:name:"aaaaaaaa"             | value:integer:13 |
      | attr:name:"aaaaaaaaa"            | value:integer:12 |
      | attr:name:"aaaaaaaaaa"           | value:integer:11 |
      | attr:name:"aaaaaaaaaaa"          | value:integer:10 |
      | attr:name:"aaaaaaaaaaaa"         | value:integer:9  |
      | attr:name:"aaaaaaaaaaaaa"        | value:integer:8  |
      | attr:name:"aaaaaaaaaaaaaa"       | value:integer:7  |
      | attr:name:"aaaaaaaaaaaaaaa"      | value:integer:6  |
      | attr:name:"aaaaaaaaaaaaaaaa"     | value:integer:5  |
      | attr:name:"aaaaaaaaaaaaaaaaa"    | value:integer:4  |
      | attr:name:"aaaaaaaaaaaaaaaaaa"   | value:integer:3  |
      | attr:name:"aaaaaaaaaaaaaaaaaaa"  | value:integer:2  |
      | attr:name:"aaaaaaaaaaaaaaaaaaaa" | value:integer:1  |

    When get answers of typeql read query
    """
      match
        $_ has name $n;
        $_ has name $n2;
        $n2 < $n;
      reduce $c = count($n2) groupby $n;
    """
    Then answer size is: 19
    Then uniquely identify answer concepts
      | n                                | c                |
      | attr:name:"aa"                   | value:integer:1  |
      | attr:name:"aaa"                  | value:integer:2  |
      | attr:name:"aaaa"                 | value:integer:3  |
      | attr:name:"aaaaa"                | value:integer:4  |
      | attr:name:"aaaaaa"               | value:integer:5  |
      | attr:name:"aaaaaaa"              | value:integer:6  |
      | attr:name:"aaaaaaaa"             | value:integer:7  |
      | attr:name:"aaaaaaaaa"            | value:integer:8  |
      | attr:name:"aaaaaaaaaa"           | value:integer:9  |
      | attr:name:"aaaaaaaaaaa"          | value:integer:10 |
      | attr:name:"aaaaaaaaaaaa"         | value:integer:11 |
      | attr:name:"aaaaaaaaaaaaa"        | value:integer:12 |
      | attr:name:"aaaaaaaaaaaaaa"       | value:integer:13 |
      | attr:name:"aaaaaaaaaaaaaaa"      | value:integer:14 |
      | attr:name:"aaaaaaaaaaaaaaaa"     | value:integer:15 |
      | attr:name:"aaaaaaaaaaaaaaaaa"    | value:integer:16 |
      | attr:name:"aaaaaaaaaaaaaaaaaa"   | value:integer:17 |
      | attr:name:"aaaaaaaaaaaaaaaaaaa"  | value:integer:18 |
      | attr:name:"aaaaaaaaaaaaaaaaaaaa" | value:integer:19 |

    When get answers of typeql read query
    """
      match
        $_ has name $n;
        $_ has name $n2;
        $n2 <= $n;
      reduce $c = count($n2) groupby $n;
    """
    Then answer size is: 20
    Then uniquely identify answer concepts
      | n                                | c                |
      | attr:name:"a"                    | value:integer:1  |
      | attr:name:"aa"                   | value:integer:2  |
      | attr:name:"aaa"                  | value:integer:3  |
      | attr:name:"aaaa"                 | value:integer:4  |
      | attr:name:"aaaaa"                | value:integer:5  |
      | attr:name:"aaaaaa"               | value:integer:6  |
      | attr:name:"aaaaaaa"              | value:integer:7  |
      | attr:name:"aaaaaaaa"             | value:integer:8  |
      | attr:name:"aaaaaaaaa"            | value:integer:9  |
      | attr:name:"aaaaaaaaaa"           | value:integer:10 |
      | attr:name:"aaaaaaaaaaa"          | value:integer:11 |
      | attr:name:"aaaaaaaaaaaa"         | value:integer:12 |
      | attr:name:"aaaaaaaaaaaaa"        | value:integer:13 |
      | attr:name:"aaaaaaaaaaaaaa"       | value:integer:14 |
      | attr:name:"aaaaaaaaaaaaaaa"      | value:integer:15 |
      | attr:name:"aaaaaaaaaaaaaaaa"     | value:integer:16 |
      | attr:name:"aaaaaaaaaaaaaaaaa"    | value:integer:17 |
      | attr:name:"aaaaaaaaaaaaaaaaaa"   | value:integer:18 |
      | attr:name:"aaaaaaaaaaaaaaaaaaa"  | value:integer:19 |
      | attr:name:"aaaaaaaaaaaaaaaaaaaa" | value:integer:20 |

    When get answers of typeql read query
    """
      match
        $_ has name $n;
        $_ has name $n2;
        $n2 != $n;
      reduce $c = count($n2) groupby $n;
    """
    Then answer size is: 20
    Then uniquely identify answer concepts
      | n                                | c                |
      | attr:name:"a"                    | value:integer:19 |
      | attr:name:"aa"                   | value:integer:19 |
      | attr:name:"aaa"                  | value:integer:19 |
      | attr:name:"aaaa"                 | value:integer:19 |
      | attr:name:"aaaaa"                | value:integer:19 |
      | attr:name:"aaaaaa"               | value:integer:19 |
      | attr:name:"aaaaaaa"              | value:integer:19 |
      | attr:name:"aaaaaaaa"             | value:integer:19 |
      | attr:name:"aaaaaaaaa"            | value:integer:19 |
      | attr:name:"aaaaaaaaaa"           | value:integer:19 |
      | attr:name:"aaaaaaaaaaa"          | value:integer:19 |
      | attr:name:"aaaaaaaaaaaa"         | value:integer:19 |
      | attr:name:"aaaaaaaaaaaaa"        | value:integer:19 |
      | attr:name:"aaaaaaaaaaaaaa"       | value:integer:19 |
      | attr:name:"aaaaaaaaaaaaaaa"      | value:integer:19 |
      | attr:name:"aaaaaaaaaaaaaaaa"     | value:integer:19 |
      | attr:name:"aaaaaaaaaaaaaaaaa"    | value:integer:19 |
      | attr:name:"aaaaaaaaaaaaaaaaaa"   | value:integer:19 |
      | attr:name:"aaaaaaaaaaaaaaaaaaa"  | value:integer:19 |
      | attr:name:"aaaaaaaaaaaaaaaaaaaa" | value:integer:19 |

    When get answers of typeql read query
    """
      match
        $_ has name $n;
        $_ has name $n2;
        $n2 == $n;
      reduce $c = count($n2) groupby $n;
    """
    Then answer size is: 20
    Then uniquely identify answer concepts
      | n                                | c               |
      | attr:name:"a"                    | value:integer:1 |
      | attr:name:"aa"                   | value:integer:1 |
      | attr:name:"aaa"                  | value:integer:1 |
      | attr:name:"aaaa"                 | value:integer:1 |
      | attr:name:"aaaaa"                | value:integer:1 |
      | attr:name:"aaaaaa"               | value:integer:1 |
      | attr:name:"aaaaaaa"              | value:integer:1 |
      | attr:name:"aaaaaaaa"             | value:integer:1 |
      | attr:name:"aaaaaaaaa"            | value:integer:1 |
      | attr:name:"aaaaaaaaaa"           | value:integer:1 |
      | attr:name:"aaaaaaaaaaa"          | value:integer:1 |
      | attr:name:"aaaaaaaaaaaa"         | value:integer:1 |
      | attr:name:"aaaaaaaaaaaaa"        | value:integer:1 |
      | attr:name:"aaaaaaaaaaaaaa"       | value:integer:1 |
      | attr:name:"aaaaaaaaaaaaaaa"      | value:integer:1 |
      | attr:name:"aaaaaaaaaaaaaaaa"     | value:integer:1 |
      | attr:name:"aaaaaaaaaaaaaaaaa"    | value:integer:1 |
      | attr:name:"aaaaaaaaaaaaaaaaaa"   | value:integer:1 |
      | attr:name:"aaaaaaaaaaaaaaaaaaa"  | value:integer:1 |
      | attr:name:"aaaaaaaaaaaaaaaaaaaa" | value:integer:1 |


  ###############
  # NAMESPACING #
  ###############
  Scenario Outline: Test unary functions with namespacing
    Given connection open read transaction for database: typedb
    When get answers of typeql read query
    """
      match let $result = <function>(<argument>);
      """
    Then uniquely identify answer concepts
      | result                       |
      | value:<result_type>:<result> |

    Examples:
      | function         | argument | result_type | result |
      | std::math::abs   | -1/2     | double      | 0.5    |
      | std::math::floor | 3/2      | integer     | 1      |
      | std::math::ceil  | 3/2      | integer     | 2      |
      | std::math::round | -11.5    | integer     | -12    |
      | std::math::log10 | 1000     | double      | 3.0    |
      | std::string::len | "12345"  | integer     | 5      |


  Scenario Outline: Test binary functions with namespacing
    Given connection open read transaction for database: typedb
    When get answers of typeql read query
    """
      match let $result = <function>(<a>, <b>);
      """
    Then uniquely identify answer concepts
      | result                       |
      | value:<result_type>:<result> |

    Examples:
      | function       | a       | b       | result_type | result  |
      | std::math::min | 10.2dec | 13.5dec | decimal     | 10.2dec |
      | std::math::max | 10.2dec | 13.5dec | decimal     | 13.5dec |
