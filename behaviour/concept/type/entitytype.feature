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

Feature: Concept Entity Type

  Background:
    Given connection has been opened
    Given connection delete all keyspaces
    Given connection does not have any keyspace
    Given connection create keyspace: grakn
    Given connection open session for keyspace: grakn
    Given session opens transaction of type: write

  Scenario: Create a new entity type
    When put entity type: person
    Then entity(person) is null: false
    Then entity(person) get supertype: entity
    When transaction commits
    When session opens transaction of type: read
    Then entity(person) is null: false
    Then entity(person) get supertype: entity

  Scenario: Delete an entity type
    When put entity type: person
    Then entity(person) is null: false
    When put entity type: company
    Then entity(company) is null: false
    When delete entity type: company
    Then entity(company) is null: true
    Then entity(entity) get subtypes do not contain:
      | company |
    When transaction commits
    When session opens transaction of type: write
    Then entity(person) is null: false
    Then entity(company) is null: true
    Then entity(entity) get subtypes do not contain:
      | company |
    When delete entity type: person
    Then entity(person) is null: true
    Then entity(entity) get subtypes do not contain:
      | person  |
      | company |
    When transaction commits
    When session opens transaction of type: read
    Then entity(person) is null: true
    Then entity(company) is null: true
    Then entity(entity) get subtypes do not contain:
      | person  |
      | company |

  Scenario: Change the label of an entity type
    When put entity type: person
    Then entity(person) is null: false
    Then entity(person) get label: person
    When entity(person) set label: horse
    Then entity(horse) is null: false
    Then entity(horse) get label: horse
    When transaction commits
    When session opens transaction of type: write
    Then entity(horse) is null: false
    Then entity(horse) get label: horse
    When entity(horse) set label: animal
    Then entity(animal) is null: false
    Then entity(animal) get label: animal
    When transaction commits
    When session opens transaction of type: read
    Then entity(animal) is null: false
    Then entity(animal) get label: animal

  Scenario: Set an entity type to be abstract
    When put entity type: person
    When entity(person) set abstract: true
    Then entity(person) is abstract: true
    Then entity(person) creates instance successfully: false
    When transaction commits
    When session opens transaction of type: read
    Then entity(person) is abstract: true
    Then entity(person) creates instance successfully: false

  Scenario: Make an entity type subtype another entity type
    When put entity type: man
    When put entity type: person
    When entity(man) set supertype: person
    Then entity(man) is null: false
    Then entity(person) is null: false
    Then entity(man) get supertype: person
    Then entity(person) get supertype: entity
    When transaction commits
    When session opens transaction of type: read
    Then entity(man) is null: false
    Then entity(person) is null: false
    Then entity(man) get supertype: person
    Then entity(person) get supertype: entity

  Scenario: Create a hierarchy of entity types subtyping each other
    When put entity type: man
    When put entity type: woman
    When put entity type: person
    When put entity type: cat
    When put entity type: animal
    When entity(man) set supertype: person
    When entity(woman) set supertype: person
    When entity(person) set supertype: animal
    When entity(cat) set supertype: animal
    Then entity(man) get supertype: person
    Then entity(woman) get supertype: person
    Then entity(person) get supertype: animal
    Then entity(cat) get supertype: animal
    Then entity(man) get supertypes contain:
      | man    |
      | person |
      | animal |
    Then entity(woman) get supertypes contain:
      | woman  |
      | person |
      | animal |
    Then entity(person) get supertypes contain:
      | person |
      | animal |
    Then entity(cat) get supertypes contain:
      | cat    |
      | animal |
    Then entity(man) get subtypes contain:
      | man |
    Then entity(woman) get subtypes contain:
      | woman |
    Then entity(person) get subtypes contain:
      | person |
      | man    |
      | woman  |
    Then entity(cat) get subtypes contain:
      | cat |
    Then entity(animal) get subtypes contain:
      | animal |
      | cat    |
      | person |
      | man    |
      | woman  |
    When transaction commits
    When session opens transaction of type: read
    Then entity(man) get supertype: person
    Then entity(woman) get supertype: person
    Then entity(person) get supertype: animal
    Then entity(cat) get supertype: animal
    Then entity(man) get supertypes contain:
      | man    |
      | person |
      | animal |
    Then entity(woman) get supertypes contain:
      | woman  |
      | person |
      | animal |
    Then entity(person) get supertypes contain:
      | person |
      | animal |
    Then entity(cat) get supertypes contain:
      | cat    |
      | animal |
    Then entity(man) get subtypes contain:
      | man |
    Then entity(woman) get subtypes contain:
      | woman |
    Then entity(person) get subtypes contain:
      | person |
      | man    |
      | woman  |
    Then entity(cat) get subtypes contain:
      | cat |
    Then entity(animal) get subtypes contain:
      | animal |
      | cat    |
      | person |
      | man    |
      | woman  |

  Scenario: Entity types can have keys
    When put attribute type: email
    When put attribute type: username
    When put entity type: person
    When entity(person) set key attribute: email
    When entity(person) set key attribute: username
    Then entity(person) get key attributes contain:
      | email    |
      | username |
    When transaction commits
    When session opens transaction of type: read
    Then entity(person) get key attributes contain:
      | email    |
      | username |

  Scenario: Entity types can remove keys
    When put attribute type: email
    When put attribute type: username
    When put entity type: person
    When entity(person) set key attribute: email
    When entity(person) set key attribute: username
    When entity(person) remove key attribute: email
    Then entity(person) get key attributes do not contain: email
    When transaction commits
    When session opens transaction of type: write
    When entity(person) remove key attribute: username
    Then entity(person) get key attributes do not contain:
      | email    |
      | username |

  Scenario: Entity types can have attributes
    When put attribute type: name
    When put attribute type: age
    When put entity type: person
    When entity(person) set has attribute: name
    When entity(person) set has attribute: age
    Then entity(person) get has attributes contain:
      | name |
      | age  |
    When transaction commits
    When session opens transaction of type: read
    Then entity(person) get has attributes contain:
      | name |
      | age  |

  Scenario: Entity types can remove attributes
    When put attribute type: name
    When put attribute type: age
    When put entity type: person
    When entity(person) set has attribute: name
    When entity(person) set has attribute: age
    When entity(person) remove has attribute: age
    Then entity(person) get has attributes do not contain: age
    When transaction commits
    When session opens transaction of type: write
    When entity(person) remove has attribute: name
    Then entity(person) get has attributes do not contain:
      | name |
      | age  |

  Scenario: Entity types can have keys and attributes
    When put attribute type: email
    When put attribute type: username
    When put attribute type: name
    When put attribute type: age
    When put entity type: person
    When entity(person) set key attribute: email
    When entity(person) set key attribute: username
    When entity(person) set has attribute: name
    When entity(person) set has attribute: age
    Then entity(person) get key attributes contain:
      | email    |
      | username |
    Then entity(person) get has attributes contain:
      | email    |
      | username |
      | name     |
      | age      |
    When transaction commits
    When session opens transaction of type: read
    Then entity(person) get key attributes contain:
      | email    |
      | username |
    Then entity(person) get has attributes contain:
      | email    |
      | username |
      | name     |
      | age      |

  Scenario: Entity types can inherit keys and attributes
    When put attribute type: email
    When put attribute type: name
    When put attribute type: reference
    When put attribute type: rating
    When put entity type: person
    When entity(person) set key attribute: email
    When entity(person) set has attribute: name
    When put entity type: customer
    When entity(customer) set supertype: person
    When entity(customer) set key attribute: reference
    When entity(customer) set has attribute: rating
    Then entity(customer) get key attributes contain:
      | email     |
      | reference |
    Then entity(customer) get has attributes contain:
      | email     |
      | reference |
      | name      |
      | rating    |
    When transaction commits
    When session opens transaction of type: write
    Then entity(customer) get key attributes contain:
      | email     |
      | reference |
    Then entity(customer) get has attributes contain:
      | email     |
      | reference |
      | name      |
      | rating    |
    When put attribute type: license
    When put attribute type: points
    When put entity type: subscriber
    When entity(subscriber) set supertype: customer
    When entity(subscriber) set key attribute: license
    When entity(subscriber) set has attribute: points
    When transaction commits
    When session opens transaction of type: read
    Then entity(customer) get key attributes contain:
      | email     |
      | reference |
    Then entity(customer) get has attributes contain:
      | email     |
      | reference |
      | name      |
      | rating    |
    Then entity(subscriber) get key attributes contain:
      | email     |
      | reference |
      | license   |
    Then entity(subscriber) get has attributes contain:
      | email     |
      | reference |
      | license   |
      | name      |
      | rating    |
      | points    |

  Scenario: Entity types can override inherited keys and attributes
    When put attribute type: username
    When put attribute type: email
    When put attribute type: name
    When put attribute type: age
    When put attribute type: reference
    When put attribute type: work-email
    When put attribute type: nick-name
    When put attribute type: rating
    When put entity type: person
    When entity(person) set key attribute: username
    When entity(person) set key attribute: email
    When entity(person) set has attribute: name
    When entity(person) set has attribute: age
    When put entity type: customer
    When entity(customer) set supertype: person
    When entity(customer) set key attribute: reference
    When entity(customer) set key attribute: work-email as email
    When entity(customer) set has attribute: rating
    When entity(customer) set has attribute: nick-name as name
    Then entity(customer) get key attributes contain:
      | username   |
      | reference  |
      | work-email |
    Then entity(customer) get key attributes do not contain:
      | email |
    Then entity(customer) get has attributes contain:
      | username   |
      | reference  |
      | work-email |
      | age        |
      | rating     |
      | nick-name  |
    Then entity(customer) get has attributes do not contain:
      | email |
      | name  |
    When transaction commits
    When session opens transaction of type: write
    Then entity(customer) get key attributes contain:
      | username   |
      | reference  |
      | work-email |
    Then entity(customer) get key attributes do not contain:
      | email |
    Then entity(customer) get has attributes contain:
      | username   |
      | reference  |
      | work-email |
      | age        |
      | rating     |
      | nick-name  |
    Then entity(customer) get has attributes do not contain:
      | email |
      | name  |
    When put attribute type: license
    When put attribute type: points
    When put entity type: subscriber
    When entity(subscriber) set supertype: customer
    When entity(subscriber) set key attribute: license as reference
    When entity(subscriber) set has attribute: points as rating
    When transaction commits
    When session opens transaction of type: read
    Then entity(customer) get key attributes contain:
      | username   |
      | reference  |
      | work-email |
    Then entity(customer) get key attributes do not contain:
      | email |
    Then entity(customer) get has attributes contain:
      | username   |
      | reference  |
      | work-email |
      | age        |
      | rating     |
      | nick-name  |
    Then entity(customer) get has attributes do not contain:
      | email |
      | name  |
    Then entity(subscriber) get key attributes contain:
      | username   |
      | license    |
      | work-email |
    Then entity(subscriber) get key attributes do not contain:
      | email     |
      | reference |
    Then entity(subscriber) get has attributes contain:
      | username   |
      | license    |
      | work-email |
      | age        |
      | points     |
      | nick-name  |
    Then entity(subscriber) get has attributes do not contain:
      | email      |
      | references |
      | name       |
      | rating     |

  Scenario: Entity types can override inherited attribute as a key
    When put attribute type: username
    When put attribute type: name
    When put entity type: person
    When entity(person) set has attribute: name
    When put entity type: customer
    When entity(customer) set supertype: person
    When entity(customer) set key attribute: username
    Then entity(customer) get key attributes contain:
      | username |
    Then entity(customer) get key attributes do not contain:
      | name |
    Then entity(customer) get has attributes contain:
      | username |
    Then entity(customer) get has attributes do not contain:
      | name |
    When transaction commits
    When session opens transaction of type: read
    Then entity(customer) get key attributes contain:
      | username |
    Then entity(customer) get key attributes do not contain:
      | name |
    Then entity(customer) get has attributes contain:
      | username |
    Then entity(customer) get has attributes do not contain:
      | name |

  Scenario: Entity types can play role types
    When put relation type: marriage
    When relation(marriage) set relates role: husband
    When put entity type: person
    When entity(person) set plays role: marriage:husband
    Then entity(person) get playing roles contain:
      | marriage:husband |
    When transaction commits
    When session opens transaction of type: write
    When relation(marriage) set relates role: wife
    When entity(person) set plays role: marriage:wife
    Then entity(person) get playing roles contain:
      | marriage:husband |
      | marriage:wife    |
    When transaction commits
    When session opens transaction of type: read
    Then entity(person) get playing roles contain:
      | marriage:husband |
      | marriage:wife    |