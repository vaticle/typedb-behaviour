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
Feature: Graql Match Clause


  Scenario: a relation is matchable from role players without specifying relation type
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
      | insert                                            |
      | $x isa person, has ref 0;                         |
      | $y isa company, has ref 1;                        |
      | $r (employee: $x, employer: $y) isa employment,   |
      |    has ref 2;                                     |
    When the integrity is validated

    Then get answers of graql query
      | match $x isa person; $r ($x) isa relation; get; |
    Then answers have concepts with ref
      | x    | r    |
      | 0    | 2    |

    Then get answers of graql query
      | match $y isa company; $r ($y) isa relation; get; |
    Then answers have concepts with ref
      | y    | r    |
      | 1    | 2    |


  Scenario: inserting a relation with named role players is retrieved without role players in all combinations
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
      | insert $p isa person, has ref 0;     |
      | $c isa company, has ref 1;           |
      | $c2 isa company, has ref 2;          |
      | $r (employee: $p, employer: $c, employer: $c) isa employment, has ref 3; |
    When the integrity is validated

    Then get answers of graql query
      | match $r ($x, $y) isa employment; get; |
    And answers have concepts with ref
      | x    | y    | r    |
      | 0    | 1    | 3    |
      | 1    | 0    | 3    |
      | 0    | 2    | 3    |
      | 2    | 0    | 3    |
      | 1    | 2    | 3    |
      | 2    | 1    | 3    |

