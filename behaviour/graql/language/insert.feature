#
# GRAKN.AI - THE KNOWLEDGE GRAPH
# Copyright (C) 2019 Grakn Labs Ltd
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
Feature: Graql Insert Query

  Scenario: insert an instance creates instance of that type
    Given graql define
      | define                               |
      | person sub entity,                   |
      |   plays employee,                    |
      |   has name;                          |
      | company sub entity,                  |
      |   plays employer;                    |
      | employment sub relation,             |
      |   relates employee,                  |
      |   relates employee;                  |
      | name sub attribute,                  |
      |   datatype string;                   |
    Given the integrity is validated

    When graql insert
      | insert                                 |
      |   $x isa person, has name $a via $imp; |
      |   $r (employee: $x) isa employment;    |
      |   $a "John" isa name;                  |
    When the integrity is validated

    Then get answers of graql query
      | match $x isa thing; get; |
    Then answer size is: 4


  Scenario: insert an additional role player is visible in the relation
    Given graql define
      | define                               |
      | person sub entity,                   |
      |   plays employee,                    |
      |   key ref;                           |
      | company sub entity,                  |
      |   plays employer,                    |
      |   key ref;                           |
      | employment sub relation,             |
      |   relates employee,                  |
      |   relates employee,                  |
      |   key ref;                           |
      | ref sub attribute, datatype long;    |
    Given the integrity is validated

    When graql insert
      | insert $p isa person, has ref 0; $r (employee: $p) isa employment, has ref 1; |
    When graql insert
      | match $r isa employment; insert $r (employer: $c) isa employment; $c isa company, has ref 2; |
    When the integrity is validated

    Then get answers of graql query
      | match $r (employer: $c, employee: $p) isa employment; get; |
    And answers have concepts with ref
      | p    | c    | r    |
      | 0    | 2    | 1    |


  Scenario: insert an attribute with a value is retrievable by the value
    Given graql define
      | define                               |
      | name sub attribute, datatype string; |
      |   key ref;                           |
      | ref sub attribute, datatype long;    |
    Given the integrity is validated

    When graql insert
      | insert $n "John" isa name, has ref 0;|
    When the integrity is validated

    Then get answers of graql query
      | match $a "John"; get; |
    And answers have concepts with ref
      | a    |
      | 0    |


  Scenario: insert an attribute that already exists throws errors when inserted with different keys
    Given graql define
      | define                                     |
      | age sub attribute, datatype long, key ref; |
      | ref sub attribute, datatype long;          |
    Given the integrity is validated

    When graql insert
      | insert $a "john" isa name, has ref 0; |
    When the integrity is validated

    Then graql insert throws
      | insert $a "john" isa name, has ref 1; |


  Scenario: insert identical attributes in parallel transactions throws errors when inserted with different keys
    Given graql define
      | define                                        |
      | name sub attribute, datatype string, key ref; |
      | ref sub attribute, datatype long;           |
    Given the integrity is validated

    Given transactions
      | tx1 |
      | tx2 |
    When graql insert in tx1
      | insert $a "john" isa name, has ref 0; |
    When graql insert in tx2
      | insert $a "john" isa name, has ref 1; |
    Then commit throws
      | tx1 |
      | tx2 |


  Scenario: insert attributes in parallel triggers deduplication
    Given graql define
      | define                              |
      | age sub attribute, datatype string; |
    Given the integrity is validated

    Given transactions
      | tx1 |
      | tx2 |
    When graql insert in parallel
      | tx1  | insert $a "john" isa name; |
      | tx2  | insert $a "john" isa name; |
    Then commit
      | tx1 |
      | tx2 |

    Then get answers of graql query
      | match $x isa name; get; |
    Then answer size is: 1


  Scenario: insert two owners of the same attribute creates two owners of the same attribute
    Given graql define
      | define                                  |
      | person sub attribute, has age, key ref; |
      | age sub attribute, datatype long;       |
      | ref sub attribute, datatype long;       |
    Given the integrity is validated

    When graql insert
      | insert $p isa person, has age 10, has ref 0; |
    When the integrity is validated

    When graql insert
      | insert $p isa person, has age 10, has ref 1; |
    When the integrity is validated

    Then get answers of graql query
      | match                        |
      | $p1 isa person, has age $a;  |
      | $p2 isa person, has age $a;  |
      | get $p1, $p2;                |
    Then answers have concepts with ref
      | $p1  | $p2  |
      | 0    | 1    |
      | 1    | 0    |


  Scenario: insert a subtype of an attribute with same value creates a separate instance


  Scenario: insert a regex attribute throws error if not conforming to regex
    Given graql define
      | define                               |
      | person sub entity,                   |
      |   has value;                         |
      | value sub attribute,                 |
      |   datatype string,                   |
      |   regex "\d{2}\.[true][false]";      |
    Given the integrity is validated

    Then graql insert throws
      | insert                               |
      |   $x isa person, has value $a ;      |
      |   $a "10.maybe";                     |
