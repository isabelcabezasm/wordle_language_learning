FROM mcr.microsoft.com/devcontainers/python:1-3.13-bookworm

# The base image currently carries a Yarn repository whose signing key has expired.
RUN rm -f /etc/apt/sources.list.d/yarn.list
