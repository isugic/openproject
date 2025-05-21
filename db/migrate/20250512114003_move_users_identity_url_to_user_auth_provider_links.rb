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

class MoveUsersIdentityUrlToUserAuthProviderLinks < ActiveRecord::Migration[8.0]
  def change
    create_table :user_auth_provider_links do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade, on_update: :cascade }
      t.references :auth_provider, null: false, foreign_key: { on_delete: :cascade, on_update: :cascade }
      t.string :external_id, null: false
      t.timestamps null: false
      t.index %i[user_id auth_provider_id], unique: true
    end

    reversible do |direction|
      direction.up do
        users_data = execute(<<-SQL.squish).values
          SELECT id, identity_url FROM users WHERE type = 'User' AND NOT (identity_url = '' OR identity_url IS NULL);
        SQL
        auth_providers_data = execute(<<-SQL.squish).values
          SELECT id, slug FROM auth_providers
        SQL

        insert_data = users_data.filter_map do |user_id, identity_url|
          slug, external_id = identity_url.split(":", 2)
          next if slug.blank? || external_id.blank?

          auth_provider_id = auth_providers_data.find { |_, auth_provider_slug| auth_provider_slug == slug }.first
          next if auth_provider_id.blank?

          "(#{user_id}, #{auth_provider_id}, '#{external_id}', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"
        end.join(",\n")

        if insert_data.present?
          execute(<<-SQL.squish).values
            INSERT INTO user_auth_provider_links (user_id, auth_provider_id, external_id, created_at, updated_at)
              VALUES #{insert_data}
              ON CONFLICT DO NOTHING
              RETURNING id
          SQL
        end
      end
    end
    remove_column :users, :identity_url, :string
  end
end
