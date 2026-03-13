# frozen_string_literal: true

# This controller enables Avo resource routes for Assignment.
# See: https://docs.avohq.io/3.0/controllers.html
module Avo
  class AssignmentsController < Avo::ResourcesController
    # Readonly belongs_to fields may not submit their value. Ensure assigned_by_user_id
    # is set so fill_record receives an ID (not a User object) for find_record.
    prepend_before_action :inject_assigned_by_user_param, only: [:create]

    private

    def inject_assigned_by_user_param
      (params[:assignment] ||= {})[:assigned_by_user_id] = current_user&.id
    end
  end
end
