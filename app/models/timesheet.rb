# frozen_string_literal: true

# Virtual model for timesheet policy authorization
# Timesheets are now generated dynamically from check-ins/check-outs
class Timesheet
  def self.model_name
    ActiveModel::Name.new(self, nil, 'Timesheet')
  end
end
