## The contents of this file are subject to the Mozilla Public License
## Version 1.1 (the "License"); you may not use this file except in
## compliance with the License. You may obtain a copy of the License
## at http://www.mozilla.org/MPL/
##
## Software distributed under the License is distributed on an "AS IS"
## basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
## the License for the specific language governing rights and
## limitations under the License.
##
## The Original Code is RabbitMQ.
##
## The Initial Developer of the Original Code is GoPivotal, Inc.
## Copyright (c) 2007-2016 Pivotal Software, Inc.  All rights reserved.


defmodule ClearParameterCommandTest do
  use ExUnit.Case, async: false
  import TestHelper

  @command ClearParameterCommand
  @vhost "test1"
  @user "guest"
  @root   "/"
  @component_name "federation-upstream"
  @key "reconnect-delay"
  @value "{\"uri\":\"amqp://\"}"

  setup_all do
    RabbitMQ.CLI.Distribution.start()
    :net_kernel.connect_node(get_rabbit_hostname)

    add_vhost @vhost

    on_exit([], fn ->
      delete_vhost @vhost
      :erlang.disconnect_node(get_rabbit_hostname)
      :net_kernel.stop()
    end)

    :ok
  end

  setup context do
    on_exit(context, fn ->
      clear_parameter context[:vhost], context[:component_name], context[:key]
    end)

    {
      :ok,
      opts: %{
        node: get_rabbit_hostname
      }
    }
  end

  test "merge_defaults: adds default vhost if missing" do
    assert @command.merge_defaults([], %{}) == {[], %{vhost: "/"}}
  end

  test "validate: argument validation" do
    assert @command.validate(["one", "two"], %{}) == :ok 
    assert @command.validate([], %{}) == {:validation_failure, :not_enough_args}
    assert @command.validate(["insufficient"], %{}) == {:validation_failure, :not_enough_args}
    assert @command.validate(["this", "is", "many"], %{}) == {:validation_failure, :too_many_args}
  end

  @tag component_name: @component_name, key: @key, vhost: @vhost
  test "run: returns error, if parameter does not exist", context do
    vhost_opts = Map.merge(context[:opts], %{vhost: context[:vhost]})

    assert @command.run(
      [context[:component_name], context[:key]],
      vhost_opts
    ) == {:error_string, 'Parameter does not exist'}
  end

  test "run: An invalid rabbitmq node throws a badrpc" do
    target = :jake@thedog
    :net_kernel.connect_node(target)
    opts = %{node: target, vhost: "/"}
    assert @command.run([@component_name, @key], opts) == {:badrpc, :nodedown}
  end


  @tag component_name: @component_name, key: @key, vhost: @vhost
  test "run: returns ok and clears parameter, if it exists", context do
    vhost_opts = Map.merge(context[:opts], %{vhost: context[:vhost]})

    set_parameter(context[:vhost], context[:component_name], context[:key], @value)

    assert @command.run(
      [context[:component_name], context[:key]],
      vhost_opts
    ) == :ok

    assert_parameter_empty(context)
  end

  @tag component_name: "bad-component-name", key: @key, value: @value, vhost: @root
  test "run: an invalid component_name returns a 'parameter does not exist' error", context do
    vhost_opts = Map.merge(context[:opts], %{vhost: context[:vhost]})
    assert @command.run(
      [context[:component_name], context[:key]],
      vhost_opts
    ) == {:error_string, 'Parameter does not exist'}

    assert list_parameters(context[:vhost]) == []
  end

  @tag component_name: @component_name, key: @key, value: @value, vhost: "bad-vhost"
  test "run: an invalid vhost returns a 'parameter does not exist' error", context do
    vhost_opts = Map.merge(context[:opts], %{vhost: context[:vhost]})

    assert @command.run(
      [context[:component_name], context[:key]],
      vhost_opts
    ) == {:error_string, 'Parameter does not exist'}
  end

  @tag component_name: @component_name, key: @key, value: @value, vhost: @vhost
  test "banner", context do
    vhost_opts = Map.merge(context[:opts], %{vhost: context[:vhost]})
    set_parameter(context[:vhost], context[:component_name], context[:key], @value)

    s = @command.banner(
      [context[:component_name], context[:key]],
      vhost_opts
    )

    assert s =~ ~r/Clearing runtime parameter/
    assert s =~ ~r/"#{context[:key]}"/
    assert s =~ ~r/"#{context[:component_name]}"/
    assert s =~ ~r/"#{context[:vhost]}"/
  end

  defp assert_parameter_empty(context) do
    parameter = context[:vhost]
                |> list_parameters
                |> Enum.filter(fn(param) ->
                    param[:component_name] == context[:component_name] and
                    param[:key] == context[:key]
                    end)
    assert parameter === []
  end
end
