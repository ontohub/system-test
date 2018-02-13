# frozen_string_literal: true

RSpec.describe 'System-Test' do
  describe 'The repository' do
    shared_examples 'exists' do
      it 'exists' do
        expect(repository_root.join(repository).directory?).to be(true)
      end
    end

    describe 'ontohub-backend' do
      let(:repository) { 'ontohub-backend' }
      include_examples 'exists'
    end

    describe 'ontohub-frontend' do
      let(:repository) { 'ontohub-frontend' }
      include_examples 'exists'
    end

    describe 'indexer' do
      let(:repository) { 'indexer' }
      include_examples 'exists'
    end

    describe 'hets-agent' do
      let(:repository) { 'hets-agent' }
      include_examples 'exists'
    end
  end

  describe 'Service availability' do
    shared_examples 'connectable' do
      it 'is given' do
        expect(system("curl --connect-timeout 30 -s #{url} > /dev/null")).
          to be(true)
      end
    end

    describe 'of the backend' do
      let(:url) { backend_url }
      include_examples 'connectable'
    end

    describe 'of the frontend' do
      let(:url) { frontend_url }
      include_examples 'connectable'
    end
  end

  describe 'Rollback invoked manually', order: :defined do
    let(:changed_repository) do
      repository_root.join('ontohub-backend/data/git/ada/fixtures.git')
    end
    let(:additional_file) { changed_repository.join('_file') }
    let(:user_name) { Faker::Name.name }
    let(:slug) { Faker::Internet.slug(user_name, '-') }

    it' There is no additional file in the beginning' do
      expect(additional_file.file?).to be(false)
    end

    it 'There is no additional user in the database' do
      command =
        %(psql --no-psqlrc -d #{database_name} -U postgres -t -c ) +
        %("SELECT * FROM organizational_units;")
      sql_result = `#{command}`
      expect(sql_result).not_to match(/#{user_name}/)
    end

    context 'When I change repository contents' do
      before do
        File.write(additional_file.to_s, 'created')
      end

      it 'there repository is changed' do
        expect(additional_file.file?).to be(true)
      end

      context 'When I do the rollback' do
        before do
          reset_backend
        end

        it 'the change in the repository is gone' do
          expect(additional_file.file?).to be(false)
        end

        it 'the repository itself still exists' do
          expect(changed_repository.directory?).to be(true)
        end
      end
    end

    context 'When I add a user to the database' do
      before do
        command =
          %(psql --no-psqlrc -d #{database_name} -U postgres -c ) +
          %("INSERT INTO organizational_units (display_name, kind, slug) ) +
          %(VALUES ('#{user_name}', 'User', '#{slug}');")
        `#{command}`
      end

      it 'the user is in the database' do
        command =
          %(psql --no-psqlrc -d #{database_name} -U postgres -t -c) +
          %("SELECT * FROM organizational_units;")
        sql_result = `#{command}`
        expect(sql_result).to match(/#{user_name}/)
      end

      context 'When I do the rollback' do
        before do
          reset_backend
        end

        it 'the user is not in the database any more' do
          command =
            %(psql --no-psqlrc -d #{database_name} -U postgres -t -c ) +
            %("SELECT * FROM organizational_units;")
          sql_result = `#{command}`
          expect(sql_result).not_to match(/#{user_name}/)
        end

        it 'but a seed user is in the database' do
          command =
            %(psql --no-psqlrc -d #{database_name} -U postgres -t -c ) +
            %("SELECT * FROM organizational_units;")
          sql_result = `#{command}`
          expect(sql_result).to match(/ada/)
        end
      end
    end
  end
end
