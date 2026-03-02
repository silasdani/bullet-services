# frozen_string_literal: true

module Avo
  class TimesheetsController < Avo::ApplicationController
    def index
      @year = (params[:year] || Time.current.year).to_i
      @month = (params[:month] || Time.current.month).to_i
      @month_start = Time.zone.local(@year, @month, 1)
      @prev = @month_start - 1.month
      @next = @month_start + 1.month
      result = Timesheets::MonthSummaryService.new(year: @year, month: @month).call
      @rows = result.rows
      @page_title = 'Timesheets'
    end
  end
end
