# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

#noinspection CucumberUndefinedStep
Feature: TypeQL Variable binding tests
  # Note: Most rules across stages are repeated in pipeline.feature
  Background: Open connection and create a simple extensible schema
    Given typedb starts
    Given connection opens with default authentication
    Given connection is open: true
    Given connection reset database: typedb
    Given connection open schema transaction for database: typedb

    Given typeql schema query
      """
      define
      entity person, owns ref @key, owns name @card(0..);
      attribute name, value string;
      attribute ref, value integer;
      attribute number @independent, value integer;

      fun none_integer() -> integer?:
      match try { let $none = 1; $none == 0; };
      return first $none;
      """
    Given transaction commits


  Scenario: Variables are available in the next stage
    Given connection open read transaction for database: typedb
    When get answers of typeql read query
    """
    match let $x = 1;
    match let $y = $x + 2;
    """
    Then uniquely identify answer concepts
      | y               |
      | value:integer:3 |


  Scenario: Variables are not available in subsequent stages if they are not selected by a select stage
    Given connection open read transaction for database: typedb
    Then typeql read query; fails with a message containing: "The variable 'x' must be bound to a value before it's used"
    """
    match
      let $x = 1;
      let $a = 2;
    select $a;
    match
      let $y = $x + 2;
    """


  Scenario: Variables are not available in subsequent stages if they are aggregated over by a reduce stage
    Given connection open read transaction for database: typedb
    Then typeql read query; fails with a message containing: "The variable 'x' must be bound to a value before it's used"
    """
    match
      let $x = 1;
    reduce $c = sum($x);
    match
      let $y = $x + 2;
    """


  Scenario: Variables which occur in all branches of a disjunction are available in the root & subsequent stages
    Given connection open read transaction for database: typedb
    When get answers of typeql read query
    """
    match
      { let $x = 1; } or { let $x = 11; };
      let $y = $x + 2;
    """
    Then uniquely identify answer concepts
      | y                |
      | value:integer:3  |
      | value:integer:13 |

    When get answers of typeql read query
    """
    match
      { let $x = 1; } or { let $x = 11; };
    match
      let $y = $x + 2;
    """
    Then uniquely identify answer concepts
      | y                |
      | value:integer:3  |
      | value:integer:13 |

    When get answers of typeql read query
    """
    # Skip a level
    match
      {
        { let $x = 1;  } or { let $x = 11;  };
      } or {
        { let $x = 6;  } or { let $x = 16;  };
      };
    match
      let $y = $x + 2;
    """
    Then uniquely identify answer concepts
      | y                |
      | value:integer:3  |
      | value:integer:13 |
      | value:integer:8  |
      | value:integer:18 |


  Scenario: Variables which occur in only some branches of a disjunction and are NOT BOUND in a parent conjunction are not available in the root & subsequent stages
    Given connection open read transaction for database: typedb
    Then typeql read query; fails with a message containing: "The variable 'x' must be bound to a value before it's used"
    """
    match
      { let $x = 1; let $a = 100; } or { let $z = 11; let $a = 100; };
      let $y = $x + 2;
    """

    Then typeql read query; fails with a message containing: "The variable 'x' must be bound to a value before it's used"
    """
    match
      { let $x = 1; let $a = 100; } or { let $z = 11; let $a = 100; };
    match
      let $y = $x + 2;
    """


  Scenario: Variables which occur in only some branches of a disjunction and ARE BOUND in a parent conjunction are available in subsequent stages
    Given connection open read transaction for database: typedb
    When get answers of typeql read query
    """
    match
      let $x = 1; let $a = 10;
      { $x < 5; $a > 5; } or { $a < 15; };
    match
      let $y = $x + 2;
    """
    Then uniquely identify answer concepts
      | y               |
      | value:integer:3 |

    When get answers of typeql read query
    """
    match
      let $a = 10;
      { let $x = 1;  } or { let $x = 11;  };
      { $x < 5; $a > 5; } or { $a < 15; };
    match
      let $y = $x + 2;
    """
    Then uniquely identify answer concepts
      | y                |
      | value:integer:3  |
      | value:integer:13 |



  Scenario: Variables which occur in only some branches of two separate disjunctions MUST BE BOUND in a common ancestor conjunction
    Given connection open read transaction for database: typedb
    When get answers of typeql read query
    """
    match
      let $x = 1; let $a = 10;
      { $x < 5; $a > 5; } or { $a < 15; };
      { $a < 20; } or { $x > 0; $a > 0; };
    match
      let $y = $x + 2;
    """
    Then uniquely identify answer concepts
      | y               |
      | value:integer:3 |

    # TODO: Might be better with disjoint variable error "Locally-scoped variable 'x' cannot be re-used elsewhere as a locally-scoped variable"
    Then typeql read query; fails with a message containing: "The variable 'x' must be bound to a value before it's used"
    """
    match
      let $a = 10;
      { let $x = 1; $x < 5; $a > 5; } or { $a < 15; };
      { $a < 20; } or { let $x = 1; $x > 0; $a > 0; };
    """


  Scenario: Variables which occur in a negation and are NOT PRESENT in a parent conjunction are local and unavailable in subsequent stages.
    Given connection open read transaction for database: typedb
    When get answers of typeql read query
    """
    match
      let $a = 10;
      not { let $x = 1; $x > 10; };
    match
      let $b = $a + 2;
    """
    Then uniquely identify answer concepts
      | b                |
      | value:integer:12 |

    Then typeql read query; fails with a message containing: "The variable 'x' must be bound to a value before it's used"
    """
    match
      let $a = 10;
      not { let $x = 1; $x > 10; };
    match
      let $y = $x + 2;
    """


  Scenario: Variables which occur in a negation and ARE PRESENT elsewhere MUST BE BOUND in the parent conjunction
    Given connection open read transaction for database: typedb
    When get answers of typeql read query
    """
    match
      let $x = 1;
      not { $x > 10; };
    match
      let $y = $x + 2;
    """
    Then uniquely identify answer concepts
      | y                |
      | value:integer:3  |

    When get answers of typeql read query
    """
    # Skip a level
    match
      let $x = 1;
      { not { $x > 10; }; } or { not { $x < 0; }; };
    match
      let $y = $x + 2;
    """
    Then uniquely identify answer concepts
      | y                |
      | value:integer:3  |


    Then typeql read query; fails with a message containing: "The variable 'x' must be bound to a value before it's used"
    """
    match
      not { let $x = 1; $x > 10; };
      let $y = $x + 2;
    """


  Scenario: It is illegal to have variables are in a negation, NOT PRESENT in a parent conjunction, and present only in some branches of a sibling disjunction.
    Given connection open read transaction for database: typedb
    Then typeql read query; fails with a message containing: "The variable 'x' must be bound to a value before it's used"
    """
    match
      let $a = 10;
      { let $x = 1; $a > 5; } or { $a < 15; };
      not { $x > 10; };
    """


  Scenario: It is illegal to have variables in two separate negations which are NOT BOUND in an ancestor conjunction.
    Given connection open read transaction for database: typedb
    When get answers of typeql read query
    """
    match
      let $x = 1;
      not { $x > 10; };
      not { $x < 0; };
      let $y = $x + 2;
    """
    Then uniquely identify answer concepts
      | y               |
      | value:integer:3 |

    Then typeql read query; fails with a message containing: "The variable 'x' must be bound to a value before it's used"
    """
    match
      not { let $x = 1; $x > 10; };
      not { let $x = 2; $x < 0; };
    """

    Then typeql read query; fails with a message containing: "The variable 'x' must be bound to a value before it's used"
    """
    # Skip a level
    match
      { not { let $x = 1; $x > 10; }; } or
      { not { let $x = 2; $x < 0;  }; };
    match
      let $y = $x + 2;
    """


  Scenario: Reassigning an argument to a return does not make it binding
    Given connection open read transaction for database: typedb
    When typeql read query; fails with a message containing: "The variable 'x' must be bound to a value before it's used"
    """
    with fun ident($x: integer) -> integer:
    match let $y = $x;
    return first $y;

    match
      let $x = ident($x);
    """

  # Unwrapping optionals
  Scenario: Referencing optional variables without an unwrap fails
    Given connection open read transaction for database: typedb
    When typeql read query; fails with a message containing: "The optional variable 'x' was used in a context where it may fail the branch if unset. Please acknowledge the optionality"
    """
    match
      try { let $x = 5; $x == 4; };
    match
      let $y = $x;
    """
    When get answers of typeql read query
    """
    match
      try { let $x = 5; $x == 4; };
    match
      isset $x;
      let $y = $x;
    """
    Then answer size is: 0

    # Optional function returns
    When typeql read query; fails with a message containing: "The optional variable 'x' was used in a context where it may fail the branch if unset. Please acknowledge the optionality"
    """
    match
      let $x = none_integer(); # Add ? when enforced
    match
      let $y = $x;
    """
    When get answers of typeql read query
    """
    match
      let $x = none_integer(); # Add ? when enforced
    match
      isset $x;
      let $y = $x;
    """
    Then answer size is: 0

    # In same stage
    When typeql read query; fails with a message containing: "The optional variable 'x' was used in a context where it may fail the branch if unset. Please acknowledge the optionality"
    """
    match
      let $x = none_integer(); # Add ? when enforced
      let $y = $x;
    """
    When get answers of typeql read query
    """
    match
      let $x = none_integer(); # Add ? when enforced
      isset $x;
      let $y = $x;
    """
    Then answer size is: 0

    # Originating from a reduce
    When typeql read query; fails with a message containing: "The optional variable 'mean' was used in a context where it may fail the branch if unset. Please acknowledge the optionality"
    """
    match
      try { let $x = 1; $x == 0; };
    reduce
      $mean = mean($x);
    match
      let $twice_mean = 2 * $mean;
    """
    When get answers of typeql read query
    """
    match
      try { let $x = 1; $x == 0; };
    reduce
      $mean = mean($x);
    match
      isset $mean;
      let $twice_mean = 2 * $mean;
    """
    Then answer size is: 0


  # TODO: Do we even want to allow this behaviour?
  Scenario: Referencing optional variables in a write stage without an unwrap fails
    Given connection open write transaction for database: typedb
    When typeql write query; fails with a message containing: "The optional variable 'x' was used in a context where it may fail the branch if unset. Please acknowledge the optionality"
    """
    match
      try { $x isa person; };
    insert
      $x has name "Steve";
    """
    Given connection open write transaction for database: typedb
    When get answers of typeql write query
    """
    match
      try { $x isa person; };
    insert
      isset $x;
      $x has name "Steve";
    """
    Then answer size is: 1
    Given transaction closes

    Given connection open write transaction for database: typedb
    When typeql write query; fails with a message containing: "The optional variable 'x' was used in a context where it may fail the branch if unset. Please acknowledge the optionality"
    """
    match
      try { $x isa person; };
    put
      $x has name "Steve";
    """
    Given connection open write transaction for database: typedb
    When get answers of typeql write query
    """
    match
      try { $x isa person; };
    put
      isset $x;
      $x has name "Steve";
    """
    Then answer size is: 1
    Given transaction closes

    Given connection open write transaction for database: typedb
    When typeql write query; fails with a message containing: "The optional variable 'x' was used in a context where it may fail the branch if unset. Please acknowledge the optionality"
    """
    match
      try { $x isa person; };
    update
      $x has ref 54321;
    """
    Given connection open write transaction for database: typedb
    When get answers of typeql write query
    """
    match
      try { $x isa person; };
    update
      isset $x;
      $x has ref 54321;
    """
    Then answer size is: 1
    Given transaction closes

    Given connection open write transaction for database: typedb
    When typeql write query; fails with a message containing: "The optional variable 'x' was used in a context where it may fail the branch if unset. Please acknowledge the optionality"
    """
    match
      try { $x isa person; };
    delete
      $x;
    """
    Given connection open write transaction for database: typedb
    When get answers of typeql write query
    """
    match
      try { $x isa person; };
    delete
      isset $x;
      $x;
    """
    Then answer size is: 1
    Given transaction closes


  Scenario: Unwrapped variables are non-optional in the pattern and all sub-patterns of the unwrap
    Given connection open read transaction for database: typedb
    When typeql read query; fails with a message containing: "The optional variable 'x' was used in a context where it may fail the branch if unset. Please acknowledge the optionality"
    """
    match
      try { let $x = 5; $x == 4; };
    match
      try { let $y = $x; };
    """
    When get answers of typeql read query
    """
    match
      try { let $x = 5; $x == 4; };
    match
      isset $x;
      try { let $y = $x; };
    """
    Then answer size is: 0

    When get answers of typeql read query
    """
    match
      try { let $x = 5; $x == 4; };
    match
      try { isset $x; let $y = $x; };
    """
    Then answer size is: 1

    When typeql read query; fails with a message containing: "The optional variable 'x' was used in a context where it may fail the branch if unset. Please acknowledge the optionality"
    """
    match
      try { let $x = 5; $x == 4; };
    match
      not { let $y = $x; };
    """
    When get answers of typeql read query
    """
    match
      try { let $x = 5; $x == 4; };
    match
      isset $x;
      not { let $y = $x; };
    """
    Then answer size is: 0
    When get answers of typeql read query
    """
    match
      try { let $x = 5; $x == 4; };
    match
      not { isset $x; let $y = $x; };
    """
    Then answer size is: 1

    When typeql read query; fails with a message containing: "The optional variable 'x' was used in a context where it may fail the branch if unset. Please acknowledge the optionality"
    """
    match
      try { let $x = 5; $x == 4; };
    match
      { let $y = $x; } or { let $z = 1; };
    """
    When get answers of typeql read query
    """
    match
      try { let $x = 5; $x == 4; };
    match
      isset $x;
      { let $y = $x; } or { let $z = 1; };
    """
    Then answer size is: 0
    When get answers of typeql read query
    """
    match
      try { let $x = 5; $x == 4; };
    match
      { isset $x; let $y = $x; } or { let $z = 1; };
    """
    Then answer size is: 1


  Scenario: Variables unwrapped in the root of a stage is unwrapped in downstream stages
    Given connection open read transaction for database: typedb
    When typeql read query; fails with a message containing: "The optional variable 'x' was used in a context where it may fail the branch if unset. Please acknowledge the optionality"
    """
    match
      try { let $x = 5; };
    match
      let $y = $x + 1;
    match
      let $z = $x + 2;
    """
    When get answers of typeql read query
    """
    match
      try { let $x = 5; };
    match
      isset $x;
      let $y = $x + 1;
    match
      let $z = $x + 2;
    """
    Then answer size is: 1

  # This would be cool behaviour but not really needed or intuitive.
  @ignore
  Scenario: Variables unwrapped in all branches of a disjunction are unwrapped in the parent
    Given connection open read transaction for database: typedb
    When typeql read query; fails with a message containing: "The optional variable 'x' was used in a context where it may fail the branch if unset. Please acknowledge the optionality"
    """
    match
      try { let $x = 5; };
    match
      { let $y = $x +1; } or { let $y = $x +2; };
    """
    When get answers of typeql read query
    """
    match
      try { let $x = 5; };
    match
      { isset $x; let $y = $x +1; } or { isset $x; let $y = $x +2; };
    match
      let $z = $x + $y;
    """
    Then answer size is: 2

