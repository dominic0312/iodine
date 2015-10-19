module Iodine

	# This is the Basic Iodine server unit - a network protocol.
	#
	# A new protocol instance will be created for every network connection.
	#
	# The recommended use is to inherit this class and override any of the following:
	# on_open:: called whenever the Protocol is initialized. Override this to initialize the Protocol object.
	# on_message(data):: called whenever data is received from the IO. Override this to implement the actual network protocol.
	# on_close:: called AFTER the Protocol's IO is closed.
	# on_shutdown:: called when the server's shutdown process had started and BEFORE the Protocol's IO is closed. It allows graceful shutdown for network protocols.
	# ping:: called when timeout was reached. see {#set_timeout}
	#
	# Once the network protocol class was created, remember to tell Iodine about it:
	#       class MyProtocol << Iodine::Protocol
	#           # your code here
	#       end
	#       # tell Iodine
	#       Iodine.protocol = MyProtocol
	#
	class Protocol

		# returns the IO object. If the connection uses SSL/TLS, this will return the SSLSocket (not a native IO object).
		#
		# Using one of the Protocol methods {#write}, {#read}, {#close} is prefered over direct access.
		attr_reader :io

		# Sets the timeout in seconds for IO activity (set timeout within {#on_open}).
		#
		# After timeout is reached, {#ping} will be called. The connection will be closed if {#ping} returns `false` or `nil`.
		def set_timeout seconds
			@timeout = seconds
		end

		# This method is called whenever the Protocol is initialized - i.e.:
		# a new connection is established or an old connection switches to this protocol.
		def on_open
		end
		# This method is called whenever data is received from the IO.
		def on_message data
		end

		# This method is called AFTER the Protocol's IO is closed - it will only be called once.
		def on_close
		end

		# This method is called when the server's shutdown process had started and BEFORE the Protocol's IO is closed. It allows graceful shutdown for network protocols.
		def on_shutdown
		end

		# This method is called whenever a timeout has occurred. Either implement a ping or return `false` to disconnect.
		#
		# A `false` or `nil` return value will cause disconnection
		def ping
			false
		end

		#############
		## functionality and helpers


		# returns true id the protocol is using an encrypted connection (the IO is an OpenSSL::SSL::SSLSocket).
		def ssl?
			@io.is_a?(OpenSSL::SSL::SSLSocket) # io.npn_protocol
		end


		# Closes the IO object.
		# @return [nil]
		def close
			@io.close unless @io.closed?
			nil
		end
		alias :disconnect :close

		# reads from the IO up to the specified number of bytes (defaults to ~2Mb).
		def read size = 2_097_152
			touch
			ssl? ? read_ssl(size) : @io.recv_nonblock( size  )
			# @io.read_nonblock( size  ) # this one is a bit slower...
		rescue OpenSSL::SSL::SSLErrorWaitReadable, IO::WaitReadable, IO::WaitWritable
			nil
		rescue IOError, Errno::ECONNRESET
			close
		rescue => e
			Iodine.warn "Protocol read error: #{e.class.name} #{e.message} (closing connection)"
			close
		end

		# this method, writes data to the socket / io object.
		def write data
			begin
				@send_locker.synchronize do
					r = @io.write data
					touch
					r
				end
			rescue => e
				close
			end
		end

		# returns the connection's unique local ID as a Hex string.
		#
		# This can be used locally but not across processes.
		def id
			@id ||= @io.to_io.to_s(16).freeze
		end

		# returns an [Enumerable](http://ruby-doc.org/core-2.2.3/Enumerable.html) with all the active connections.
		#
		# if a block is passed, than this method exceutes the block.
		def self.each
			if block_given?
				Iodine.to_a.each {|p| yield(p) if p.is_a?(self) }
			else
				( Iodine.to_a.select {|p| p.is_a?(self) } ).each
			end
		end


		#################
		## the following are Iodine's "system" methods, used internally. Don't override.


		# This method is used by Iodine to initialized the Protocol.
		#
		# A new Protocol instance set itself up as the IO's protocol (replacing any previous protocol).
		#
		# Normally you won't need to override this method. Override {#on_open} instead.
		def initialize io
			@timeout ||= nil
			@send_locker = Mutex.new
			@locker = Mutex.new
			@io = io
			touch
			@locker.synchronize do
				Iodine.switch_protocol @io.to_io, self
				on_open
			end
		end

		# Called by Iodine whenever there is data in the IO's read buffer.
		#
		# Normally you won't need to override this method. Override {#on_message} instead.
		def call
			return unless @locker.try_lock
			begin
				data = read
				if data
					on_message(data)
					data.clear
				end
			ensure
				@locker.unlock
			end
		end


		# This method is used by Iodine to ask whether a timeout has occured.
		#
		# Normally you won't need to override this method. See {#ping}
		def timeout? time
			(ping || close) if @timeout && !@send_locker.locked? && ( (time - @last_active) > @timeout )
		end



		# This method is used by Iodine to create the IO handler whenever a new connection is established.
		#
		# Normally you won't need to override this method.
		def self.accept io, ssl
			ssl ? SSLConnector.new(io, self) :  self.new(io)
		end

		protected

		# This methos updates the timeout "watch", signifying the IO was active.
		def touch
			@last_active = Iodine.time
		end

		# reads from the IO up to the specified number of bytes (defaults to ~1Mb).
		def read_ssl size
			@send_locker.synchronize do
				data = ''
				begin
					 (data << @io.read_nonblock(size).to_s) until data.bytesize >= size
				rescue OpenSSL::SSL::SSLErrorWaitReadable, IO::WaitReadable, IO::WaitWritable

				rescue IOError
					close
				rescue => e
					Iodine.warn "SSL Protocol read error: #{e.class.name} #{e.message} (closing connection)"
					close
				end
				return false if data.to_s.empty?
				touch
				data
			end
		end


	end

end