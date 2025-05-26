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
class EnterpriseTokensController < ApplicationController
  include OpTurbo::DialogStreamHelper
  include OpTurbo::ComponentStream

  layout "admin"
  menu_item :enterprise

  before_action :require_admin
  before_action :check_user_limit, only: [:index]
  before_action :find_token, only: %i[destroy destroy_dialog]

  def index
    # TODO: delete next line. @current_token is used in the old angular thingy.
    # It should not be needed anymore then.
    @current_token = EnterpriseToken.active_tokens.first
  end

  def new
    respond_with_dialog Admin::EnterpriseTokens::CreateDialogComponent.new(EnterpriseToken.new)
  end

  def create # rubocop:disable Metrics/AbcSize
    @token = EnterpriseToken.new
    saved_encoded_token = @token.encoded_token
    @token.encoded_token = params[:enterprise_token][:encoded_token]
    if @token.save
      flash[:notice] = t(:notice_successful_update)
      respond_to do |format|
        format.html { redirect_to action: :index, status: :see_other }
        format.json { head :no_content }
      end
    else
      # restore the old token
      if saved_encoded_token
        @token.encoded_token = saved_encoded_token
        @current_token = @token || EnterpriseToken.new
      end
      respond_to do |format|
        format.html { render action: :index, status: :unprocessable_entity }
        format.json { render json: { description: @token.errors.full_messages.join(", ") }, status: :bad_request }
        format.turbo_stream do
          component = Admin::EnterpriseTokens::FormComponent.new(@token)
          update_via_turbo_stream(component: component)
          render turbo_stream: turbo_streams, status: :unprocessable_entity
        end
      end
    end
  end

  def destroy_dialog
    respond_with_dialog Admin::EnterpriseTokens::DeleteDialogComponent.new(@token)
  end

  def destroy
    if @token.destroy
      flash[:notice] = t(:notice_successful_delete)
    else
      flash[:error] = t(:error_failed_to_delete_entry)
    end

    delete_trial_key
    redirect_to action: :index
  end

  def save_trial_key
    Token::EnterpriseTrialKey.create(user_id: User.system.id, value: params[:trial_key])
  end

  def delete_trial_key
    Token::EnterpriseTrialKey.where(user_id: User.system.id).delete_all
  end

  private

  def find_token
    EnterpriseToken.find(params[:id])
  end

  def check_user_limit
    if OpenProject::Enterprise.user_limit_reached?
      flash.now[:warning] = I18n.t(
        "warning_user_limit_reached_instructions",
        current: OpenProject::Enterprise.active_user_count,
        max: OpenProject::Enterprise.user_limit
      )
    end
  end
end
