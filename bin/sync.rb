#!/usr/bin/env ruby

require_relative "../config"
require_relative "../lib/bank_sync"

LOGGER.info "Starting bank sync..."
BankSync.new.sync_transactions
LOGGER.info "Bank sync completed!"
