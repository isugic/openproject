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
class EnterpriseToken < ApplicationRecord
  class << self
    def all_tokens
      all.sort_by(&:sort_key)
    end

    def active_tokens
      RequestStore.fetch(:current_ee_tokens) do
        set_active_tokens
      end
    end

    def active_non_trial_tokens
      active_tokens.reject(&:trial?)
    end

    def active_trial_tokens
      active_tokens.select(&:trial?)
    end

    def table_exists?
      connection.data_source_exists? table_name
    end

    def allows_to?(feature)
      active_tokens.any? { |token| Authorization::EnterpriseService.new(token).call(feature).result }
    end

    def active?
      active_tokens.any?
    end

    def hide_banners?
      OpenProject::Configuration.ee_hide_banners?
    end

    def available_features
      active_tokens.map(&:available_features).flatten.uniq
    end

    def user_limit
      non_trial_user_limit.presence || trial_user_limit
    end

    def non_trial_user_limit
      active_non_trial_tokens.map { |token| Hash(token.restrictions)[:active_user_count] }.max
    end

    def trial_user_limit
      active_trial_tokens.map { |token| Hash(token.restrictions)[:active_user_count] }.max
    end

    def banner_type_for(feature:)
      if !active?
        :no_token
      elsif !allows_to?(feature)
        :upsell
      end
    end

    def set_active_tokens
      EnterpriseToken
        .order(Arel.sql("created_at DESC"))
        .to_a
        .reject(&:expired?)
    end

    def clear_current_tokens_cache
      RequestStore.delete :current_ee_tokens
    end
  end

  FAR_FUTURE_DATE = Date.new(9999, 1, 1)
  private_constant :FAR_FUTURE_DATE

  validates :encoded_token, presence: true
  validate :valid_token_object
  validate :valid_domain

  before_save :clear_current_tokens_cache
  before_destroy :clear_current_tokens_cache

  delegate :will_expire?,
           :trial?,
           :subscriber,
           :mail,
           :company,
           :domain,
           :issued_at,
           :starts_at,
           :expires_at,
           :reprieve_days,
           :reprieve_days_left,
           :restrictions,
           :available_features,
           :plan,
           :features,
           :version,
           to: :token_object

  def token_object
    load_token! unless defined?(@token_object)
    @token_object
  end

  def allows_to?(action)
    Authorization::EnterpriseService.new(self).call(action).result
  end

  delegate :clear_current_tokens_cache, to: :EnterpriseToken

  def expired?(reprieve: true)
    token_object.expired?(reprieve:) || invalid_domain?
  end

  ##
  # The domain is only validated for tokens from version 2.0 onwards.
  def invalid_domain?
    return false unless token_object&.validate_domain?

    !token_object.valid_domain?(Setting.host_name)
  end

  def sort_key
    [expires_at || FAR_FUTURE_DATE, starts_at || FAR_FUTURE_DATE]
  end

  private

  def load_token!
    @token_object = OpenProject::Token.import(encoded_token)
  rescue OpenProject::Token::ImportError => e
    Rails.logger.error "Failed to load EE token: #{e}"
    nil
  end

  def valid_token_object
    errors.add(:encoded_token, :unreadable) unless load_token!
  end

  def valid_domain
    errors.add :domain, :invalid if invalid_domain?
  end
end
