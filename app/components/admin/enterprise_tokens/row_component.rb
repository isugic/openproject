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
  class RowComponent < ::OpPrimer::BorderBoxRowComponent
    alias :token :model
    delegate :subscriber, :domain, to: :token

    def token
      model
    end

    def email
      token.mail
    end

    def plan
      helpers.enterprise_token_plan_name(token)
    end

    def active_users
      if token.restrictions.nil? || token.restrictions[:active_user_count].blank?
        I18n.t("js.admin.enterprise.upsell.unlimited")
      else
        token.restrictions[:active_user_count]
      end
    end

    def dates
      [
        helpers.format_date(token.starts_at),
        token.will_expire? ? helpers.format_date(token.expires_at) : I18n.t("js.admin.enterprise.upsell.unlimited")
      ].join(" – ")
    end

    def button_links
      [
        action_menu
      ]
    end

    def action_menu
      render(Primer::Alpha::ActionMenu.new) do |menu|
        menu.with_show_button(icon: "kebab-horizontal",
                              "aria-label": t(:label_more),
                              scheme: :invisible,
                              data: {
                                "test-selector": "more-button"
                              })

        delete_action(menu)
      end
    end

    def delete_action(menu)
      menu.with_item(label: I18n.t(:button_delete),
                     scheme: :danger,
                     href: destroy_dialog_enterprise_token_path(token),
                     tag: :a,
                     content_arguments: {
                       data: { controller: "async-dialog" }
                     }) do |item|
        item.with_leading_visual_icon(icon: :trash)
      end
    end
  end
end
