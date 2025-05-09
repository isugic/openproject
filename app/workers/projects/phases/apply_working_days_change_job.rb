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

class Projects::Phases::ApplyWorkingDaysChangeJob < ApplicationJob
  include JobConcurrency
  queue_with_priority :above_normal

  good_job_control_concurrency_with(
    total_limit: 1
  )

  attr_reader :previous_working_days, :previous_non_working_days

  def perform(user_id:, previous_working_days:, previous_non_working_days:)
    @previous_working_days = previous_working_days
    @previous_non_working_days = previous_non_working_days

    user = User.find(user_id)

    User.execute_as user do
      # TODO: find all active phases with date range affected by changes
      # TODO: group by project
      # TODO: call RescheduleService on phases of that project starting with the one with smallest definition position
    end
  end
end
