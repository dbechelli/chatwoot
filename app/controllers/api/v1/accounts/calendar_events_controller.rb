class Api::V1::Accounts::CalendarEventsController < Api::V1::Accounts::BaseController
  before_action :fetch_calendar_event, only: [:show, :update, :destroy]

  def index
    @calendar_events = Current.account.calendar_events
    if params[:start_date] && params[:end_date]
      start_date = Time.zone.parse(params[:start_date])
      end_date = Time.zone.parse(params[:end_date])
      @calendar_events = @calendar_events.between(start_date, end_date)
    end
    render json: @calendar_events
  end

  def show
    render json: @calendar_event
  end

  def create
    @calendar_event = Current.account.calendar_events.new(calendar_event_params)
    @calendar_event.user = current_user
    if @calendar_event.save
      if params[:calendar_event][:notify]
        # Send notification logic here
        # NotificationBuilder.new(...)
      end
      render json: @calendar_event
    else
      render_error_response(@calendar_event)
    end
  end

  def update
    if @calendar_event.update(calendar_event_params)
      render json: @calendar_event
    else
      render_error_response(@calendar_event)
    end
  end

  def destroy
    @calendar_event.destroy
    head :ok
  end

  private

  def fetch_calendar_event
    @calendar_event = Current.account.calendar_events.find(params[:id])
  end

  def calendar_event_params
    params.require(:calendar_event).permit(:title, :description, :start_time, :end_time)
  end
end
