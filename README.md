# Integration Runner (RPA)

## Overview

The Integration Runner is a Ruby-based application that automates browser interactions using `Watir`. It is designed to run integrations, process data, and generate reports. This application utilizes the `Chromium` headless browser for efficiency and `CSV` files for output data storage. The program is containerized using Docker, making it portable and easy to deploy.

---
### Table of Contents

[Integration Runner (RPA)](#integration-runner-rpa)
   - [Overview](#overview)
[Setup and Usage](#setup-and-usage)
   - [Prerequisites](#prerequisites)
     - [Recommended](#recommended)
     - [Local](#local)
   - [Running Locally (Without Docker)](#running-locally-without-docker)
   - [Running with Docker (Recommended w/ Docker)](#running-with-docker-recommended-w-docker)
[Output and Logs](#output-and-logs)
[File Structure and Descriptions](#file-structure-and-descriptions)
   - [1. `app/integration_runner.rb`](#1-appintegration_runnerrb)
   - [2. `app/main.rb`](#2-appmainrb)
   - [3. `Dockerfile`](#3-dockerfile)
   - [4. `docker-compose.yml`](#4-docker-composeyml)
   - [5. `run_rpa.sh`](#5-run_rpash)
   - [6. `run_history.csv`](#6-run_historycsv)
[What's Next?!](#whats-next)
   - [Security Considerations](#security-considerations)
   - [Further Customizable Settings](#further-customizable-settings)

## Setup and Usage

### Prerequisites

##### Recommended
- **[Docker Desktop](https://www.docker.com/products/docker-desktop/):** Installed and running on the host machine.

##### Local 
- **[Ruby](https://www.ruby-lang.org/en/documentation/installation/):** Version 3.2 or higher. I recommend [rbenv](https://github.com/rbenv/rbenv#readme) for version management.
- **[Chromium](https://www.chromium.org/chromium-projects/):** Install handled by Docker image or `Watir`.

### Running Locally (Without Docker)

1. Install required gems:
   ```bash
   bundle install
   ```
2. Run the application:
   ```bash
   ruby app/main.rb --run
   ```

### Running with Docker (Recommended w/ Docker)

1. Build and run the application using `run_rpa.sh`:
   ```bash
   ./run_rpa.sh --run
   ```
2. To generate a report for a specific `run_id`:
   ```bash
   ./run_rpa.sh --report <UUID>
   ```

---

## Output and Logs

- **Run Logs:** Output to the console using `Logger`.
- **Data Files:**
  - `run_history.csv`: A auto-generated cumulative log of all integration runs.
  - `data/data.csv`: Temporary CSV files generated during integration runs (automatically deleted after processing).

---
## File Structure and Descriptions

### 1. `app/integration_runner.rb`

This file defines the main functionality of the Integration Runner.

- **Purpose:** Automates the integration process, logs run details, and processes exported CSV data.
- **Key Features:**
  - **Browser Automation:** Uses `Watir` to automate browser actions like logging in, navigating to specific pages, and running integrations.
  - **Data Processing:** Extracts specific information from downloaded CSV files and logs it in a consolidated history file (`run_history.csv`).
  - **Error Handling:** Manages timeouts and other browser-related errors, ensuring smooth operation and proper logging.
  - **Reusable Methods:** Encapsulates key tasks like login, integration execution, and data extraction into private methods for modularity.

---

### 2. `app/main.rb`

The entry point for the application.

- **Purpose:** Provides a CLI interface to run new integrations or generate reports on past runs.
- **Features:**
  - **Command-Line Options:**
    - `--run`: Executes a new integration run.
    - `--report <UUID>`: Generates a report for a specific integration run.
  - **Integration with `IntegrationRunner`:** Delegates execution to the core logic defined in `integration_runner.rb`.

---

### 3. `Dockerfile`

The Dockerfile defines the container environment for the application.

- **Purpose:** Builds a lightweight, portable image for running the application.
- **Key Instructions:**
  - Uses the official `ruby:3.2-slim` base image.
  - Installs dependencies like `chromium` and `chromium-driver` for headless browser operations.
  - Copies application files and installs Ruby gems using Bundler.
  - Sets the default command to run `app/main.rb`.

---

### 4. **`docker-compose.yml`**
Manages containerized services:
- **Purpose:** Simplifies container orchestration for development and execution.
- **Features:**
  - **Service Definition:** Creates a service named `rpa` (Robotic Process Automation).
  - **Volume Mounting:** Maps the local project directory to the container's `/app` directory for real-time file updates.
  - **TTY (`tty: true`)**: Allocates a pseudo-TTY for interactive processes, ensuring compatibility with command-line tools.
  - **Standard Input (`stdin_open: true`)**: Keeps the container's standard input open, enabling interactive debugging or shell access.

---

### 5. `run_rpa.sh`

A helper script for running the application with Docker Compose.

- **Purpose:** Automates Docker Compose commands for building and running the application.
- **Features:**
  - Builds the Docker image before running the application.
  - Gracefully handles cleanup of Docker resources upon script termination.
  - Accepts command-line arguments and passes them to `main.rb`.

---

### 6. `run_history.csv`

- **Purpose:** Stores historical data of integration runs. It's volumized within the Docker app directory
- **Structure:**
  - `timestamp`: The start time of the integration.
  - `run_id`: A unique identifier for the run.
  - `status`: The final status of the integration (`Complete`, `Errored`, etc.).
  - `actions`: The total number of actions performed.
  - `things`: JSON-encoded details of extracted items.

---

## What's Next?!

- **Security Considerations:**
  - Credentials (`user_id`, `password`) are hardcoded for simplicity. Replace with environment variables or a secrets manager in production.
- **Further Customizable Settings:**
  - Modify browser options in `BROWSER_OPTIONS` to adjust headless browser behavior.
  - Update the `BADGE_IDS` array to toggle specific filters during post-run processing. They are currently hardcoded to toggle `Deleted, Warning, Errored`.
