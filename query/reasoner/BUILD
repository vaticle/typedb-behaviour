#
# Copyright (C) 2022 Vaticle
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

package(default_visibility = ["//visibility:public"])

load("@vaticle_dependencies//tool/checkstyle:rules.bzl", "checkstyle_test")

files = [
    "attribute-attachment.feature",
    "compound-queries.feature",
    "concept-inequality.feature",
    "negation.feature",
    "recursion.feature",
    "relation-inference.feature",
    "schema-queries.feature",
    "rule-interaction.feature",
    "type-hierarchy.feature",
    "variable-roles.feature",
]

filegroup(
    name = "features",
    srcs = files,
)

exports_files(files)

checkstyle_test(
    name = "checkstyle",
    include = glob(["*"]),
    license_type = "agpl-header",
)