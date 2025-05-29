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

module ProjectLifeCycleSteps
  class ActivationService < ::BaseServices::BaseContracted
    alias_method :project, :model

    attr_reader :definitions

    def initialize(user:, project:, definitions:, contract_class: nil, contract_options: {})
      super(user:, contract_class:, contract_options:)
      self.model = project
      @definitions = definitions
    end

    private

    def persist(service_call)
      active = params[:active]

      upsert(active:)

      if (phase = reschedule_from_phase)
        UpdateService.new(user:, model: phase).call
      else
        project.touch_and_save_journals

        service_call
      end
    end

    def upsert(active:)
      Project::Phase.upsert_all(
        definitions.map do |definition|
          {
            project_id: project.id,
            definition_id: definition.id,
            active:
          }
        end,
        unique_by: %i[project_id definition_id]
      )
    end

    def reschedule_from_phase
      first_definition = definitions.min_by(&:position)
      return unless first_definition

      phase = project.phases.find_by(definition_id: first_definition.id)
      preceding_active_phase(phase) || phase
    end

    def preceding_active_phase(phase)
      project.available_phases.reverse.find { it.date_range_set? && it.position < phase.position }
    end

    def default_contract_class
      ProjectLifeCycleSteps::ActivationContract
    end
  end
end
