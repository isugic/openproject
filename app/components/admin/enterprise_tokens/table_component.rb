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

module Admin::EnterpriseTokens
  class TableComponent < ::OpPrimer::BorderBoxTableComponent
    columns :plan, :subscriber, :active_users, :email, :domain, :dates

    mobile_columns :plan, :subscriber, :active_users, :dates

    mobile_labels :project_name

    main_column :plan

    def sortable?
      false
    end

    def paginated?
      false
    end

    def has_actions?
      true
    end

    def mobile_title
      EnterpriseToken.model_name.plural
    end

    def headers
      @headers ||= [
        [:plan, { caption: EnterpriseToken.human_attribute_name(:plan) }],
        [:subscriber, { caption: EnterpriseToken.human_attribute_name(:subscriber) }],
        [:active_users, { caption: EnterpriseToken.human_attribute_name(:active_user_count_restriction) }],
        [:email, { caption: EnterpriseToken.human_attribute_name(:email) }],
        [:domain, { caption: EnterpriseToken.human_attribute_name(:domain) }],
        [:dates, { caption: I18n.t(:label_dates) }],
      ].compact
    end
  end
end
