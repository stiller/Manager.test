require 'bunny'

class HomeController < ApplicationController

  # Opens a client connection to the RabbitMQ service, if one isn't
  # already open.  This is a class method because a new instance of
  # the controller class will be created upon each request.  But AMQP
  # connections can be long-lived, so we would like to re-use the
  # connection across many requests.
  def self.client
    unless @client
      c = Bunny.new("amqp://localhost")
      c.start
      @client = c
    end
    @client
  end

  # Return the "nameless exchange", pre-defined by AMQP as a means to
  # send messages to specific queues.  Again, we use a class method to
  # share this across requests.requests
  def self.nameless_exchange
    @nameless_exchange ||= client.exchange('')
  end

  # Return a queue named "messages".  This will create the queue on
  # the server, if it did not already exist.  Again, we use a class
  # method to share this across requests.
  def self.messages_queue
    @messages_queue ||= client.queue("messages")
  end

  # The action for our publish form.
  def publish
    retries = 0
    # Send the message from the form's input box to the "messages"
    # queue, via the nameless exchange.  The name of the queue to
    # publish to is specified in the routing key.
    begin
      logger.info "MESSAGE #{params[:message]}"
      HomeController.nameless_exchange.publish params[:message],
                                             :content_type => "text/plain",
                                             :key => "messages"
      logger.info HomeController.messages_queue.status
      # Notify the user that we published.
      flash[:published] = true
      redirect_to home_index_path
    rescue
      logger.info "PUBLISH RESCUE"
      #if retries < 10
        #retries += 1
        #retry
      #else
        flash[:server_error] = true
        redirect_to home_index_path
      #end
    end
  end

  def index
     retries = 0
     logger.info HomeController.messages_queue.status

    # Synchronously get a message from the queue
    begin
      #binding.pry
      msg = HomeController.messages_queue.pop
    rescue
      #if retries < 10
        #retries += 1
        #retry
      #else
      logger.info "RESCUE!!!"
        msg = nil
      #end
    end
    if msg && msg[:payload] != :queue_empty
      Page.first.update_attribute :body, msg[:payload]
    end
    @body = Page.first.body
  end

end
