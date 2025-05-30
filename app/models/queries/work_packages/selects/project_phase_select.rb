# frozen_string_literal: true

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

class Queries::WorkPackages::Selects::ProjectPhaseSelect < Queries::WorkPackages::Selects::WorkPackageSelect
  def initialize
    super(:project_phase,
          association: :project_phase_definition,
          group_by_column_name: :project_phase_definition,
          sortable: sortable_statement,
          groupable: group_by_statement,
          groupable_join: group_by_join_statement,
          groupable_select: groupable_select
    )
  end

  def groupable_select
    Arel.sql(
      <<~SQL.squish
        CASE WHEN COALESCE(pd.id, 0) = 0 THEN NULL ELSE COALESCE(pd.id, 0) END AS project_phase_definition_id
      SQL
    )
  end

  def group_by_statement
    "COALESCE(pd.id, 0)"
  end

  def order_for_count
    Arel.sql(
      <<~SQL.squish
        CASE WHEN COALESCE(pd.id, 0) = 0 THEN 1 ELSE 0 END
      SQL
    )
  end

  # Is called when the query is grouped by project phase definition.
  # We ensure that only active project phases are considered.
  def group_by_join_statement
    <<~SQL.squish
      LEFT OUTER JOIN (
        SELECT d.id, d.position
        FROM project_phase_definitions d
        JOIN project_phases ph ON ph.definition_id = d.id
        JOIN projects p ON ph.project_id = p.id
        WHERE ph.active = true
        GROUP BY d.id
      ) pd
      ON project_phase_definition_id = pd.id
    SQL
  end

  def sortable_join_statement(_query)
    # Replicate the group by join to ensure the same conditions are applied (and the same alias for the join is used)
    group_by_join_statement
  end

  def sortable_statement
    # We use the join alias from the group by join statement to ensure that work packages with an *inactive* project
    # phase are treated like work packages *without* a project phase. In the result list, they will belong to the
    # same group: without an active project phase.
    "COALESCE(pd.position, -1)"
  end

  def self.instances(context = nil)
    allowed = if context
                OpenProject::FeatureDecisions.stages_and_gates_active? &&
                  User.current.allowed_in_project?(:view_project_phases, context)
              else
                OpenProject::FeatureDecisions.stages_and_gates_active? &&
                  User.current.allowed_in_any_project?(:view_project_phases)
              end

    if allowed
      [new]
    else
      []
    end
  end
end
