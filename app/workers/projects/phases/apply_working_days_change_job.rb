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

class Projects::Phases::ApplyWorkingDaysChangeJob < ApplyWorkingDaysChangeJobBase
  private

  def apply_working_days_change
    user = User.current

    applicable_phases.group(:project_id).pluck(:project_id, "ARRAY_AGG(id)").each do |project_id, phase_ids|
      project = Project.find_by(id: project_id)
      next unless project

      phases = project.available_phases.drop_while { !it.id.in?(phase_ids) }
      next if phases.empty?

      from = phases.first.start_date

      ProjectLifeCycleSteps::RescheduleService.new(user:, project:).call(phases:, from:)

      project.journal_cause = journal_cause

      project.touch_and_save_journals
    end
  end

  def applicable_phases
    days_of_week = changed_days.keys
    dates = changed_non_working_dates.keys

    Project::Phase
      .active # TODO: should visible be used?
      .covering_dates_and_days_of_week(days_of_week:, dates:)
  end
end
