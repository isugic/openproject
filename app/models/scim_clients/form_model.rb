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

module ScimClients
  FormModel = Data.define(:name, :auth_provider_id, :authentication_method, :jwt_sub) do
    extend ActiveModel::Naming

    class << self
      def from_client(client)
        identity_url = client&.service_account&.identity_url || ""
        _, jwt_sub = identity_url.split(":", 2)
        new(
          name: client.name,
          auth_provider_id: client.auth_provider_id,
          authentication_method: authentication_method(client),
          jwt_sub:
        )
      end

      def from_params(params)
        new(
          name: params[:name],
          auth_provider_id: params[:auth_provider_id],
          authentication_method: params[:authentication_method],
          jwt_sub: params[:jwt_sub]
        )
      end

      private

      def authentication_method(client)
        return AUTHENTICATION_SSO if client&.service_account&.identity_url.present?

        AUTHENTICATION_OAUTH_APPLICATION
      end
    end
  end

  class FormModel
    AUTHENTICATION_METHODS = [
      AUTHENTICATION_SSO = "sso",
      AUTHENTICATION_OAUTH_APPLICATION = "oauth2"
    ].freeze
  end
end
