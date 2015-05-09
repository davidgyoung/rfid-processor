class ReaderEventsController < ApplicationController
  before_action :set_reader_event, only: [:show, :edit, :update, :destroy]
  skip_before_action :verify_authenticity_token, if: :json_request?

  # GET /reader_events
  # GET /reader_events.json
  def index
    ReaderEvent.where("created_at < :time", {:time => 3.minutes.ago}).each{|event| event.destroy}
    @reader_events = ReaderEvent.all.order(flow_number: :asc, id: :asc)
  end

  # GET /reader_events/1
  # GET /reader_events/1.json
  def show
  end

  # GET /reader_events/new
  def new
    @reader_event = ReaderEvent.new
  end

  # GET /reader_events/1/edit
  def edit
  end

  # POST /reader_events
  # POST /reader_events.json
  def create
    @reader_event = ReaderEvent.new(reader_event_params)

    respond_to do |format|
      if @reader_event.save
        format.html { redirect_to @reader_event, notice: 'Reader event was successfully created.' }
        format.json { render action: 'show', status: :created, location: @reader_event }
      else
        format.html { render action: 'new' }
        format.json { render json: @reader_event.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /reader_events/1
  # PATCH/PUT /reader_events/1.json
  def update
    respond_to do |format|
      if @reader_event.update(reader_event_params)
        format.html { redirect_to @reader_event, notice: 'Reader event was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @reader_event.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /reader_events/1
  # DELETE /reader_events/1.json
  def destroy
    @reader_event.destroy
    respond_to do |format|
      format.html { redirect_to reader_events_url }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_reader_event
      @reader_event = ReaderEvent.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def reader_event_params
      params.require(:reader_event).permit(:flow_number, :event, :tag_id, :reader_id)
    end
  protected
    def json_request?
      puts "is this a json request? #{request.format.json?}, #{request.headers["Content-Type"]}"
      true # request.format.json?
    end
end
