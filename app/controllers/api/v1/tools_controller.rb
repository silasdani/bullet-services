# frozen_string_literal: true

module Api
  module V1
    # Read-only list of repair tools with default prices. Single source of truth for all clients.
    class ToolsController < Api::V1::BaseController
      skip_before_action :authenticate_user!, only: [:index]
      skip_before_action :check_user_blocked, only: [:index]

      def index
        render_success(data: { tools: Tool.repair_tools_for_api })
      end
    end
  end
end
