
import { FlexContainer, Flex } from "./../../components";
import { EmojiHappyIcon } from '@heroicons/react/outline';

export const Settings = () => {
  return (
    <>
      <div className="page-header">
        <FlexContainer
          direction="row"
          justify="space-between"
          align="flex-start"
        >
          <Flex>
            <h2 className="font-semibold text-2xl mb-5">Settings</h2>
          </Flex>
        </FlexContainer>
      </div>
      <div className="no-data"><EmojiHappyIcon/>You have nothing to tune yet</div>
    </>
  );
}

export default Settings;
